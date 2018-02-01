original_dir <- getwd()
setwd(file.path(original_dir, "T184089", "data"))

dimensions <- function(dataset) {
  if (dataset == "retained_installers") {
    return(c("channel", "country", "play_country"))
  } else {
    return(c("app_version", "carrier", "country", "language", "os_version", "overview"))
    # 'device' is excluded
  }
}

# Create directories for the files:
datasets <- c("installs", "ratings", "retained_installers")
for (dataset in datasets) {
  for (dimension in dimensions(dataset)) {
    if (!dir.exists(file.path(dataset, dimension))) {
      dir.create(file.path(dataset, dimension), recursive = TRUE)
    }
  }
}; rm(dataset, dimension)

zipped_files <- dir("downloads", pattern = "\\.zip$")
# ^ downloaded files from https://play.google.com/apps/publish/

temporary_dir <- file.path(tempdir(), "unzipped")
if (!dir.exists(temporary_dir)) dir.create(temporary_dir)
if (!dir.exists("renamed")) dir.create("renamed")

# Unzip files and organize them:
for (zipped_file in zipped_files) {
  unzip(file.path("downloads", zipped_file), exdir = temporary_dir)
  dataset <- stringr::str_extract(zipped_file, "([a-z\\_]+)")
  dataset <- strtrim(dataset, nchar(dataset) - 4)
  unzipped_files <- dir(temporary_dir, pattern = glue::glue("{dataset}.*\\.csv"))
  for (dimension in dimensions(dataset)) {
    old_filename <- stringr::str_subset(unzipped_files, pattern = glue::glue("^{dataset}.*_{dimension}\\.csv"))
    if (length(old_filename[1]) == 1) {
      new_filename <- stringr::str_replace(old_filename, ".*_([0-9]{4})([0-9]{2})_.*", "\\1-\\2.csv")
      file.copy(file.path(temporary_dir, old_filename), file.path(dataset, dimension, new_filename), overwrite = TRUE)
      # file.rename(file.path(temporary_dir, old_filename), file.path(dataset, dimension, new_filename))
    } else {
      warning(glue::glue("Didn't find a CSV file for {dataset}::{dimension} in {zipped_file}"))
    }
  }
  renamed_zip <- paste0(dataset, "--", sub(".csv", ".zip", new_filename, fixed = TRUE))
  file.copy(file.path("downloads", zipped_file), file.path("renamed", renamed_zip))
  file.remove(dir(temporary_dir, full.names = TRUE)) # cleanup
}; rm(zipped_file, dataset, unzipped_files, dimension, old_filename, new_filename, renamed_zip)

if (!dir.exists("concatenated")) dir.create("concatenated")

for (dataset in datasets) {
  for (dimension in dimensions(dataset)) {
    files <- dir(file.path(dataset, dimension), pattern = "\\.csv$", full.names = TRUE)
    data <- lapply(files, function(file) {
      data <- read.csv(file, fileEncoding = "UCS-2LE", stringsAsFactors = FALSE, header = TRUE)
      if (any(data$Package.Name == "Package Name")) {
        message("Discovered the duplicate bug")
        data <- data[1:(which(data$Package.Name == "Package Name") - 1), ]
      }
      colnames(data) <- gsub(".", " ", colnames(data), fixed = TRUE)
      return(data)
    })
    readr::write_csv(dplyr::bind_rows(data), file.path("concatenated", glue::glue("{dataset}-{dimension}.csv")))
  }
}; rm(files, data, dataset, dimension)

setwd(original_dir); rm(list = ls()) # reset
