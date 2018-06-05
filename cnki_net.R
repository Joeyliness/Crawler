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

#--------------------------------------------------- Page Options ---------------------------------------------------#

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

#------------------------------------------------- Page Options End -------------------------------------------------#

sum <- list()
ab  <- list()
while (TRUE) {

  # Crawl page table, the '[[5]]' varies with different page
  destination <- remDr$getPageSource()[[1]] %>% read_html(encoding = 'utf-8')
  table       <- html_table(destination, header = T, fill = T)[[5]]
  sum         <- rbind(sum, table)
  
  # Check if there is a next-page button
  pagebutton <- destination %>% html_nodes('div.TitleLeftCell a:last-child') %>% html_text()
  
  # Open each article in child window
  abstracts <- remDr$findElements('css', 'a.fz14')
  for (abstract in abstracts) {abstract$clickElement()}
  
  # Crawl title & abstract in each child window, close each of them after crawling
  allwindow  <-remDr$getWindowHandles()
  currwindow <- remDr$getCurrentWindowHandle()
  for (window in allwindow) {
    if (window != currwindow) {
      remDr$switchToWindow(window)
      destination <- remDr$getPageSource()[[1]] %>% read_html(encoding = 'utf-8')
      title       <- destination %>% html_nodes('h2.title') %>% html_text()
      if (length(title) == 0) {title = NA}
      content     <- destination %>% html_nodes('div.wxBaseinfo p label + span') %>% html_text()
      if (length(content) == 0) {content = NA}
      keyword     <- destination %>% html_nodes('label#catalog_KEYWORD ~ a') %>% html_text() %>% str_trim() %>% paste0(., collapse = '')
      if (length(keyword) == 0) {keyword = NA}
      ab          <- rbind(ab, data.frame(title, content, keyword))
      remDr$closeWindow()
    }
  }
  
  # Back to main window's frame
  remDr$switchToWindow(currwindow[[1]])
  remDr$switchToFrame(webElem[[2]])
  
  # Go to next page if there is a next-page button
  if (length(pagebutton) == 0) {
    break
  } else {
    nextpage <- remDr$findElement('css', 'div.TitleLeftCell font.Mark + a')
    nextpage$clickElement()
  }
}

# Merge info and save
remDr$close()
result <- merge(sum, ab, by.x = '篇名', by.y = 'title', all.x = TRUE)
write.csv(result, row.names = F, 'result.csv')

# Check omissions
omission <- setdiff(sum$篇名, ab$title)


#--------------------------------------------------- Download ---------------------------------------------------#

# Articles we would like to download 
articlename <- read.csv(file.choose(), sep = '\t', header = F, encoding = 'utf-8') %>% .$V1 %>% as.vector()

# Downloading
downloadrecord <- list()
for (i in seq_along(articlename)) {
      
  if (!(articlename[i] %in% names(downloadrecord))) {
    cat(paste("Downloading", i, articlename[i]))
    remDr$navigate("http://kns.cnki.net/kns/brief/default_result.aspx")
        
    # Dropdown button
    select  <- remDr$findElement('class', 'searchw8')
    select$clickElement()
        
    # 主题（nth-child(1)）；全文（nth-child(2)）；篇名（nth-child(3)）；作者（nth-child(4)）；单位（nth-child(5)）；关键词（nth-child(6)）
    # 摘要（nth-child(7)）；参考文献（nth-child(8)）；中图分类号（nth-child(9)）；文献来源（nth-child(10)）
    option  <- remDr$findElement('css', 'select.searchw8 option:nth-child(3)')
    option$clickElement()
    
    # Input article name
    keyElem <- remDr$findElement('class', 'rekeyword')
    keyElem$sendKeysToElement(list(articlename[i], key = 'enter'))
    
    webElem <- remDr$findElements("css", "iframe")
    remDr$switchToFrame(webElem[[2]])
        
    Sys.sleep(8)
    
    # Click download button
    downloadbutton <- remDr$findElement('css', 'a.briefDl_Y')
    downloadbutton$clickElement()
        
    # Crawl title
    destination <- remDr$getPageSource()[[1]] %>% read_html(., encoding = 'utf-8')
    title <- destination %>% html_node('a.fz14') %>% html_text()
        
    # Download record    
    downloadrecord[[i]] <- title
    names(downloadrecord)[[i]] <- title
        
    cat('Done.')
    cat('\n')
  }
}

compare <- data.frame(articlename, unlist(downloadrecord))
names(compare) <- c('articlename', 'downloadrecord')
omission <- setdiff(compare$articlename, compare$downloadrecord)

#------------------------------------------------- End Download -------------------------------------------------#

# Reference: https://stackoverflow.com/questions/26559192/open-a-new-tab-in-rselenium
# https://stackoverflow.com/questions/38904264/rselenium-switching-windows-using-window-handle
