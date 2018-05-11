library(tidyverse)
library(magrittr)

feed_names <- c("News", "On this day", "Continue reading", "Trending articles", "Main page", "Random", "Featured article", "Featured Image", "Because you read")

load("data/feed_last_config.RData")
load("data/dau.RData")
load("data/daily_feed_config.RData")

total_users <- nrow(feed_last_config)
default_mask <- feed_last_config$event_enabledList == "1,1,1,1,1,1,1,1,1" & feed_last_config$event_orderList == "0,1,2,3,4,5,6,7,8"
1-sum(default_mask)/total_users
sum(feed_last_config$event_enabledList != "1,1,1,1,1,1,1,1,1")/(total_users - sum(default_mask))
sum(feed_last_config$event_orderList != "0,1,2,3,4,5,6,7,8")/(total_users - sum(default_mask))
sum(feed_last_config$event_enabledList != "1,1,1,1,1,1,1,1,1" & feed_last_config$event_orderList != "0,1,2,3,4,5,6,7,8")/(total_users - sum(default_mask))

feed_last_enabled <- do.call(rbind, strsplit(feed_last_config$event_enabledList, ",", fixed = TRUE))
feed_last_enabled <- as.data.frame(apply(feed_last_enabled, 2, as.numeric))
names(feed_last_enabled) <- feed_names
sum(rowSums(feed_last_enabled) == 9) / nrow(feed_last_enabled) # 0.8071075 users navigate to the screen keep every feed on
# Out of users who disable at lease 1 feed, break down by number of enable feed
feed_last_enabled %>%
  filter(rowSums(.) != 9) %>%
  mutate(total_disabled = as.factor(9-rowSums(.))) %>%
  group_by(total_disabled) %>%
  tally %>%
  mutate(prop = n/sum(n)) %>%
  ggplot(aes(total_disabled, n)) +
  geom_bar(stat = "identity") +
  labs(x="Number of disabled card", y="Number of users",
       title="Number of users by number of disabled cards, as of February 6 2018",
       subtitle = "In total, 67468 users disable at least one card")

# Breakdown by type of feed
data.frame(card = feed_names, n = nrow(feed_last_enabled) - colSums(feed_last_enabled)) %>%
  ggplot(aes(x= reorder(card,-n), n)) +
  geom_bar(stat = "identity") +
  labs(x="Type of feed card", y="Number of users",
       title="Number of users by type of disabled card, as of February 6 2018",
       subtitle = "In total, 67468 users disable at least one card")

# Daily disabled rate by card type
daily_feed_config <- daily_feed_config[daily_feed_config$date != as.Date("2018-02-06"), ]
daily_disable <- do.call(rbind, strsplit(daily_feed_config$event_enabledList, ",", fixed = TRUE))
daily_disable <- as.data.frame(apply(daily_disable, 2, as.numeric))
daily_disable <- data.frame(daily_feed_config$date, daily_disable)
names(daily_disable) <- c("date", feed_names)
daily_disable_rate <- daily_disable %>%
  group_by(date) %>%
  summarise_all(function(x) sum(x == 0))
daily_disable_rate <- cbind(daily_disable_rate[,1], daily_disable_rate[, -1]/dau$Android_DAU[dau$date >= as.Date("2017-12-09")])
daily_disable_rate %>%
  gather(card, disable_rate, -date) %>%
  ggplot(aes(x=date, y=disable_rate, group=card, color=card)) +
  geom_line(size = 1.2) +
  scale_x_date(name = "Date", date_breaks = "1 week", date_labels = "%A\n%b %d") +
  scale_y_continuous(labels = scales::percent, name = "Disable Rate") +
  # geom_vline(xintercept = as.numeric(as.Date("2017-12-08")),
  #            linetype = "dashed", color = "black") +
  # annotate("text", x = as.Date("2017-12-07"), y = 0.0005, label = "v2.7.221 Released", angle = 90) +
  scale_color_brewer("Card", palette = "Paired") +
  labs(title = "Daily proportion of active users who disable the feed") +
  wmf::theme_min(base_size = 15)




feed_last_order <- do.call(rbind, strsplit(feed_last_config$event_orderList, ",", fixed = TRUE))
feed_last_order <- apply(feed_last_order, 2, as.numeric) + 1 # make all the numbers > 0 for later calculation

# The card's name for each position
# order enabled list by user order
enabled_mask <- as.matrix(feed_last_enabled)
for (row in 1:nrow(feed_last_enabled)) {
  enabled_mask[row, ] <- enabled_mask[row, feed_last_order[row, ]]
}
# remove disabled cards from order list
card_on_position <- as.data.frame(feed_last_order * enabled_mask)
# remove records keep default settings
card_on_position <- card_on_position[!default_mask, ]
# shift disabled cards to the back
card_on_position <- t(apply(card_on_position, 1, function(x) {
  c(x[x!=0], x[x==0])
}))
card_on_position <- as.data.frame(apply(card_on_position, 2, function(y) {
  dplyr::recode(y, `1`="News", `2`="On this day", `3`="Continue reading", `4`="Trending articles",
                `5`="Main page", `6`="Random", `7`="Featured article", `8`="Featured Image", `9`="Because you read", `0`="No enabled card")
}))
names(card_on_position) <- paste(scales::ordinal(1:9), "card")
count_by_card <- lapply(card_on_position, function(x) as.data.frame.table(table(x)))
count_by_card <- dplyr::bind_rows(count_by_card, .id="card_order")
# ggplot pie chart
ggplot(count_by_card, aes(x=1, y=Freq, fill=x)) +
  geom_col() +
  coord_polar("y") +
  geom_text(aes(x = 1.6, label = scales::percent(Freq/nrow(card_on_position))), position = position_stack(vjust = 0.5), size = 3) +
  scale_fill_brewer("Feed card", palette = "Paired") +
  theme_void() +
  facet_wrap(~card_order) +
  labs(title = "Proportion of feed cards on each position, as of February 6 2018") +
  wmf::theme_facet(clean_xaxis = TRUE, panel.grid=element_blank(), border = FALSE,
                   axis.ticks.y = element_blank(), axis.text.y=element_blank(),
                   axis.title.y = element_blank(), axis.title.x = element_blank(),
                   panel.spacing = unit(c(-1, -1), "lines"),
                   strip.background = element_rect(fill = rgb(0, 1.0, 0, 0.2)))


# Card's position
# Function to get the order of cards ignoring the diabled ones
order_cards <- function(vector) {
  sort_index <- sort.int(vector, index.return=TRUE)
  result <- rep(NA, length(vector))
  result[sort_index$x]<-sort_index$ix
  return(result)
}
position_of_card <- feed_last_order * enabled_mask
position_of_card[position_of_card == 0] <- NA
position_of_card <- position_of_card[!default_mask, ]
position_of_card <- as.data.frame(t(apply(position_of_card, 1, order_cards)))
names(position_of_card) <- feed_names
avg_position <- data.frame(card = feed_names, avg_pos = colMeans(position_of_card, na.rm = TRUE), default_pos = 1:9)
avg_position$card <- factor(avg_position$card, levels = feed_names)
avg_position$direction <- ifelse(avg_position$avg_pos-1:9 > 0, "Down", "Up")

ggplot(avg_position, aes(avg_pos, card, label = round(avg_pos, 2))) +
  geom_segment(aes(x = default_pos, y = card, xend = avg_pos, yend = card, color = direction), arrow = arrow(length = unit(0.2, "cm")), size = 2) +
  geom_text(nudge_y = 0.2) +
  scale_color_brewer("Move direction", palette = "Set1") +
  labs(x="Average Position", y="Feed Cards", title="Average card position among users who change the default feed settings, as of February 6 2018") +
  wmf::theme_min()

# Daily average position for each card
daily_order <- do.call(rbind, strsplit(daily_feed_config$event_orderList, ",", fixed = TRUE))
daily_order <- apply(daily_order, 2, as.numeric) + 1
enabled_mask <- as.matrix(daily_disable[, -1])
for (row in 1:nrow(daily_disable)) {
  enabled_mask[row, ] <- enabled_mask[row, daily_order[row, ]]
}
daily_position <- daily_order * enabled_mask
daily_position[daily_position == 0] <- NA
daily_position <- as.data.frame(t(apply(daily_position, 1, order_cards)))
daily_position <- cbind(daily_feed_config$date, daily_position)
names(daily_position) <- c("date", feed_names)
dau <- dau[dau$date >= as.Date("2017-12-09"), ]

daily_avg_pos_all <- daily_position %>%
  group_by(date) %>%
  summarise_all(function(x) sum(x, na.rm=TRUE))
daily_avg_pos_all <- cbind(daily_avg_pos_all[,1],
                           (daily_avg_pos_all[, -1] + matrix(rep(dau$Android_DAU - as.vector(table(daily_position$date)), 9)*rep(1:9, each=nrow(daily_avg_pos_all)), ncol=9))/(matrix(rep(dau$Android_DAU, 9), ncol=9)*(1-daily_disable_rate[,-1]))
)
daily_avg_pos_all %>%
  gather(card, avg_pos, -date) %>%
  ggplot(aes(x=date, y=avg_pos, group=card, color=card)) +
  geom_line(size = 1.2) +
  scale_x_date(name = "Date", date_breaks = "1 week", date_labels = "%A\n%b %d") +
  scale_y_continuous(name = "Average Position") +
  # geom_vline(xintercept = as.numeric(as.Date("2017-12-08")),
  #            linetype = "dashed", color = "black") +
  # annotate("text", x = as.Date("2017-12-07"), y = 2, label = "v2.7.221 Released", angle = 90) +
  scale_color_brewer("Card", palette = "Paired") +
  labs(title = "Daily average positon of feed cards among all active users", subtitle = "Proportion of daily active users who change the order of card is very tiny, so we can barely see any change on the average position.") +
  wmf::theme_min(base_size = 15)

daily_avg_pos <- daily_position %>%
  group_by(date) %>%
  summarise_all(function(x) mean(x, na.rm=TRUE))
default_pos <- data.frame(card = feed_names, pos=1:9)
daily_avg_pos %>%
  gather(card, avg_pos, -date) %>%
  ggplot(aes(x=date, y=avg_pos, group=card, color=card)) +
  geom_line(size = 1.3) +
  scale_x_date(name = "Date", date_breaks = "1 week", date_labels = "%A\n%b %d") +
  scale_y_continuous(name = "Average Position", breaks = 1:9) +
  geom_hline(aes(yintercept = pos, color=card), default_pos, linetype = "dashed", size = 1.3) +
  # geom_vline(xintercept = as.numeric(as.Date("2017-12-08")),
  #            linetype = "dashed", color = "black") +
  # annotate("text", x = as.Date("2017-12-07"), y = 2, label = "v2.7.221 Released", angle = 90) +
  scale_color_brewer("Card", palette = "Paired") +
  labs(title = "Daily average positon of feed cards among all users who changed default settings", subtitle = "Dash lines represent the default position of each card") +
  wmf::theme_min(base_size = 15)
