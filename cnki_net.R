library(rvest)
library(RSelenium)
shell("java -jar D:/R/library/Rwebdriver/selenium-server-standalone-3.7.1.jar", 
      wait = FALSE, invisible = FALSE)
remDr <- remoteDriver(browserName = "chrome")
remDr$open()
remDr$navigate("http://kns.cnki.net/kns/brief/default_result.aspx") 

# Input key word
keyElem <- remDr$findElement('class', 'rekeyword')
keyElem$sendKeysToElement(list('短文本分类', key = 'enter'))

#################################### Page Options ####################################

# 文献（SCDB）；期刊（CJFQ）；博硕士（CDMD）；会议（CIPD）；报纸（CCND）；外文文献（WWDB）
# 年鉴（CYFD）；百科（CRPD）；词典（CRDD）；统计数据（CSYD）；专利（SCOD）
type <- remDr$findElement('css', 'li#CJFQ') # 期刊
type$clickElement()

# Switch to frame, the '[[2]]' varies with different page 
webElem <- remDr$findElements("css", "iframe")
remDr$switchToFrame(webElem[[2]])

# 每页10条（nth-child(1)）；每页20条（nth-child(2)）；每页50条（nth-child(3)）
shownum <- remDr$findElement('css', 'div.class_grid_display_num a:nth-child(2)') # 每页20条
shownum$clickElement()

# 按照主题排序（nth-child(2)）；按照发表时间排序（nth-child(3)）；按照被引排序（nth-child(4)）；按照下载排序（nth-child(5)）
time <- remDr$findElement('css', 'tbody tr td span:nth-child(3)') # 按照发表时间排序
time$clickElement()

# 显示列表：showlist <- remDr$findElement('css', 'span.ZYcur a');showlist$clickElement()
# 显示摘要：showabstract <- remDr$findElement('css', 'span.LBcur a');showabstract$clickElement()

################################## Page Options End ##################################

sum <- list()
ab  <- list()
while (TRUE) {

  # Crawl page table, the '[[5]]' varies with different page
  destination <- remDr$getPageSource()[[1]] %>% read_html(., encoding = 'utf-8')
  table       <- html_table(destination, header = T, fill = T)[[5]]
  sum         <- rbind(sum, table)
  
  # Check if there is a next-page button
  pagebuttom <- destination %>% html_nodes('div.TitleLeftCell a:last-child') %>% html_text()
  
  # Open each article in child window
  abstracts <- remDr$findElements('css', 'a.fz14')
  for (abstract in abstracts) {abstract$clickElement()}
  
  # Crawl title & abstract in each child window, close each of them after crawling
  allwindow  <-remDr$getWindowHandles()
  currwindow <- remDr$getCurrentWindowHandle()
  for (window in allwindow) {
    if (window != currwindow) {
      remDr$switchToWindow(window)
      destination <- remDr$getPageSource()[[1]] %>% read_html(., encoding = 'utf-8')
      title       <- destination %>% html_nodes('h2.title') %>% html_text()
      if (length(title) == 0) {title = NA}
      content     <- destination %>% html_nodes('div.wxBaseinfo p label+span') %>% html_text()
      if (length(content) == 0) {content = NA}
      ab          <- rbind(ab, data.frame(title, content))
      remDr$closeWindow()
    }
  }
  
  # Back to main window's frame
  remDr$switchToWindow(currwindow[[1]])
  remDr$switchToFrame(webElem[[2]])
  
  # Go to next page if there is a next-page button
  if (length(pagebuttom) == 0) {
    break
  } else {
    nextpage <- remDr$findElement('css', 'div.TitleLeftCell font.Mark+a')
    nextpage$clickElement()
  }
}

# Merge info and save
remDr$close()
result <- merge(sum, ab, by.x = '篇名', by.y = 'title')
write.csv(result, row.names = F, 'result.csv')