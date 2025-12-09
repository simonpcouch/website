library(ggplot2)

theme_set(
  theme_gray(base_size = 11.5) +
    theme(
      plot.background = element_rect(fill = "#fdfdfb", color = NA),
      panel.background = element_rect(fill = "#fdfdfb", color = NA),
      panel.grid.major = element_line(color = "#e5e5e0"),
      panel.grid.minor = element_line(color = "#ededea"),
      axis.ticks = element_line(color = "#e5e5e0"),
      strip.background = element_rect(fill = "#fdfdfb", color = NA),
      plot.margin = margin(10, 10, 10, 10),
      plot.subtitle = element_text(face = "italic")
    )
)
