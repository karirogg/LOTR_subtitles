library(tidyverse)
library(dplyr)
library(tidyr)
library(lubridate)

#movies=c("fotr2.srt", "ttt2.srt", "rotk2.srt")
movies=c("fotr_subtitles.srt","ttt_subtitles.srt", "rotk_subtitles.srt")
dat = data.frame(movie=c(), startTime=c(), endTime=c(), text=c(), stringsAsFactors = F)

for(movie in movies) {
    currentString = ""
    currentTime = ""
    k=0
    temp = readChar(movie, file.info(movie)$size)
    subtitles = unlist(strsplit(temp, split="\n"))
    for(subtitle in subtitles) {
        if(grepl("-->", subtitle)) {
            if(currentString != "" && currentTime != "") {
                currentString=trimws(tolower(gsub(pattern = '\\d|<i>|</i>|\\.|:|,|\\r|\\?|\\!|\\-|"|\\(|\\)',"", currentString)))
                currentTime=gsub(pattern = "\\r","", currentTime)
                splitTime = unlist(strsplit(currentTime, " "))[c(1,3)] %>% hms() %>% period_to_seconds()
                dat = rbind(dat, data.frame(movie=movie, startTime=floor(splitTime[1]), endTime=ceiling(splitTime[2]), text=currentString, stringsAsFactors = F))
                currentString = ""
            } 
            currentTime = subtitle
            k = k+1
            
        } else {
            currentString = paste(currentString, subtitle, sep=" ")
        }
    }
}

dat = dat %>% separate_rows(., text, sep=" ") %>% mutate(nwords=1)

tmp_dat <- dat %>%
    mutate(text2=c(text[2:nrow(.)],""),
           checkTime=c(startTime[2:nrow(.)],""))%>%
    filter(checkTime==startTime)

while(any(tmp_dat$text2!="")){
    tmp_dat <- tmp_dat %>%
        mutate(text=paste(text,text2,sep=" "),
               nwords=max(dat$nwords)+1)
        
    
    dat <- bind_rows(dat,select(tmp_dat,movie,startTime,endTime,text,nwords))
    
    tmp_dat <- tmp_dat %>%
        mutate(text2=c(text2[2:nrow(.)],""),
               checkTime=c(startTime[2:nrow(.)],""))%>%
        filter(checkTime==startTime)
}
    
songs = c("survive.lrc", "winnertakes.lrc", "Bohemian.lrc", "doesmother.lrc", "Wonderwall.lrc", "loseyourself.lrc")
lyricsdat = data.frame(songname=c(), nword=c(), word=c(), stringsAsFactors = F)

for (song in songs) {
    rawlyr = readChar(song, file.info(song)$size)
    subbedlyr = rawlyr %>% sub("\\[[0-9][0-9]:[0-9][0-9].[0-9][0-9]\\]","\303\241",.) %>% gsub("\\[|\\]", " ", .) %>% gsub("\\.|\\,|\\?|\\!|\\n|\\:|\\-|\\d|\\(|\\)", "", .) %>% tolower()
    templyr = unlist(strsplit(subbedlyr, split="\303\241"))
    splitlyr = unlist(strsplit(templyr[2], split=" "))
    splitlyr = splitlyr[splitlyr != ""]
    lyricsdat = rbind(lyricsdat, data.frame(songname=song, nword=1:length(splitlyr), word=splitlyr, stringsAsFactors = F))
}

totaldat = left_join(lyricsdat, dat, by=c("word"="text"))

uniquematch = group_by(totaldat, songname, nword, word) %>% summarize(movie = movie[1], startTime=startTime[1], endTime=endTime[1]) %>% ungroup()
uniquematchrandom = group_by(totaldat, songname, nword, word) %>% sample_n(size = 1) %>% ungroup()
matches = inner_join(uniquematch, uniquematchrandom, by=c("songname", "nword", "word"), suffix=c("","_random"))

group_by(uniquematch, songname) %>% summarize(sum(!is.na(movie))/n())

#meikar meiri sens ad skila frames ad minu mati thar sem sekundur passa ekki endilega vid frame timestampinn
#skilum vector af frames sem python scriptid loopar i gegnum
survive_unique_matches = uniquematchrandom %>% filter(., songname == "survive.lrc")

shartmixdat =  bind_rows(
  (filter(dat, grepl("pet", text)) %>% slice(1) %>% rename(word = text) %>% mutate(nword = 8)),
  (filter(dat, text == "ring") %>% slice(1) %>% rename(word = text) %>% mutate(nword = 8)),
  (filter(dat, grepl("fried", text)) %>% slice(1) %>% rename(word = text) %>% mutate(nword = 8)),
  (filter(dat, grepl("pace", text)) %>% slice(1) %>% rename(word = text) %>% mutate(nword = 50)),
  (filter(dat, grepl("o'clock", text)) %>% slice(1) %>% rename(word = text) %>% mutate(nword = 72)),
  (filter(dat, grepl("brother", text)) %>% slice(1) %>% rename(word = text) %>% mutate(nword = 93)),
  (filter(dat, grepl("crumble", text)) %>% slice(1) %>% rename(word = text) %>% mutate(nword = 127)),
  (filter(dat, text == "because") %>% slice(1) %>% rename(word = text) %>% mutate(nword = 127)))

survive_final_dat = bind_rows(survive_unique_matches, shartmixdat) %>% arrange(nword) %>% filter(!is.na(startTime), nword <= 176)

write.table(survive_final_dat,"survive_frames.tsv", sep="\t", row.names=F, quote = F)

write.table(frameVec, file="frames.tsv", sep="\t", col.names=F, row.names=F, quote = F)

write.table(matches, file="matches.tsv", sep="\t", row.names = F, quote = F)

group_by(dat, text) %>% summarize(count = n()) %>% arrange(desc(count)) %>% View

needed = filter(uniquematch, songname == "survive.lrc", is.na(movie), nword <= 176) %>% distinct(word) %>% unlist() %>% unname()