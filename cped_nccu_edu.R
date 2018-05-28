library(rvest)
library(RSelenium)
library(stringi)
shell("java -jar D:/R/library/Rwebdriver/selenium-server-standalone-3.7.1.jar", 
      wait = FALSE, invisible = FALSE)
remDr <- remoteDriver(browserName = "chrome")
remDr$open()

# all data.csv（all Chinese names in pinyin）
data <- read.csv(file.choose(), encoding = 'utf-8', header = F) %>% .$V1 %>% as.vector()
Info <- list()
for (i in seq_along(data)) {
  url <- 'http://cped.nccu.edu.tw/listhan'
  remDr$navigate(url)
  
  # Locate to the "input" search box
  subElem <- remDr$findElement('name', 'field_re_han_name_value')
  
  # Clear default information in search box
  subElem$clearElement()
  subElem$sendKeysToElement(list(c(data[i]), key = 'enter'))
  
  # If there is no search results（show “資料庫無任何記錄”）, skip to next person
  emp <- remDr$getPageSource()[[1]] %>% read_html(encoding = "utf-8")
  if (emp %>% html_nodes('div.view-empty') %>% html_text() %>% length == 1) {
    next
  } else {
    
    # Locate to the link if person information is available and click
    personElem <- remDr$findElement(value = '//span[@class="field-content"]/a[@href]')
    personurl <- personElem$getElementAttribute('href')
    personElem$clickElement()
    
    # Crawl page content
    destination <- remDr$getPageSource()[[1]] %>% read_html(encoding = "utf-8")
    baseinfo    <- destination %>% html_nodes(., xpath = '//table[@id="basic-info"]') %>% html_text() %>% 
                   gsub('\t', '', .) %>% gsub('\n', ' ', .) %>% stri_trim_both()
    name        <- destination %>% html_nodes('h1.title') %>% html_text()
    
    degree      <- destination %>% 
                   html_nodes(., xpath = '//div[@class="field field-name-field-re-degree field-type-list-text field-label-hidden"]') %>%
                   html_text()
    if (length(degree) == 0) {degree = NA}
        
    abroadexp   <- destination %>% 
                   html_nodes(., xpath = '//div[@class="field field-name-field-re-abroad-exp field-type-list-text field-label-hidden"]') %>%
                   html_text()
    if (length(abroadexp) == 0) {abroadexp = NA}
        
    abroadcoun  <- destination %>% 
                   html_nodes(., xpath = '//div[@class="field field-name-field-re-abroad-country field-type-list-text field-label-hidden"]') %>% 
                   html_text()
    if (length(abroadcoun) == 0) {abroadcoun = NA}
        
    worktime    <- destination %>% 
                    html_nodes(., xpath = '//div[@class="field field-name-field-re-work-time field-type-text field-label-hidden"]') %>%
                    html_text()
    if (length(worktime) == 0) {worktime = NA}
          
  }
  sum  <- data.frame(name, degree, abroadexp, abroadcoun, worktime, baseinfo) 
  Info <- rbind(Info, sum)
  Sys.sleep(3)
}

remDr$close()
write.csv(Info, row.names = F, 'Info.csv')
