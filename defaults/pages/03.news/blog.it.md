---
title: 'Notizie'
# The news of the site: its posts in the folders below (<year>/<month>/<post>/item.md), the last first; the home page of the grid
# shows the last three (the w4os plugin)
content:
  items: '@self.descendants'
  filter:
    type: item
  order:
    by: date
    dir: desc
  limit: 10
  pagination: true
---
