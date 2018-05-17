library(rvest)
library(RSelenium)
library(stringi)

# all data.csv（all Chinese names in pinyin）
data <- read.csv(file.choose(), encoding = 'UTF-8', header = F) %>% .$V1 %>% as.vector()

# start Selenium server
shell("java -jar D:/R/library/Rwebdriver/selenium-server-standalone-3.7.1.jar", 
      wait = FALSE, invisible = FALSE)

# open Chrome-connect to webpage-input each name-web crawling
Info <- list()
remDr <- remoteDriver(browserName = "chrome")
remDr$open()
for (i in seq_along(data)) {
  url <- 'http://cped.nccu.edu.tw/listhan'
  remDr$navigate(url)
  
  # locate to the "input" search box
  subElem <- remDr$findElement(using = 'name', value = 'field_re_han_name_value')
  
  # clear default information in search box
  subElem$clearElement()
  subElem$sendKeysToElement(list(c(data[i]), key = 'enter'))
  
  # searching with no result（show “資料庫無任何記錄”），skip to next person
  emp <- remDr$getPageSource()[[1]] %>% read_html(encoding = "UTF-8")
  if (emp %>% html_nodes('div.view-empty') %>% html_text() %>% length == 1) {
    next
  } else {
    
    # locate to the link if person information is available
    personElem <- remDr$findElement(value = '//span[@class="field-content"]/a[@href]')
    personurl <- personElem$getElementAttribute('href')
    
    # click the located link
    personElem$clickElement()
    
    # get page content
    destination <- remDr$getPageSource()[[1]] %>% read_html(encoding = "UTF-8")
    baseinfo    <- destination %>% html_nodes(., xpath = '//table[@id="basic-info"]') %>% html_text() %>% 
                   gsub('\t', '', .) %>% gsub('\n', ' ', .) %>% stri_trim_both() 
    Info[[i]]   <- baseinfo
    Sys.sleep(3)
  }
}

# close Chrome
remDr$close()
