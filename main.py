import requests
from bs4 import BeautifulSoup
import os
import csv
from datetime import datetime, timedelta,timezone

from pprint import pprint

root1 = "https://www.gitasupersite.iitk.ac.in/{bookname}?htrskd=1&language={lang}&field_chapter_value={chapter}&field_nsutra_value={sutra}"
root = "https://www.gitasupersite.iitk.ac.in/{bookname}?language={lang}&field_chapter_value={chapter}&field_nsutra_value={sutra}&htrskd=1&hcchi=1&etsiva=1&choose=1"
Template = '''
---
title: "{title}"
date: {ts}
draft: false
chapter: {chapter}
sutra: {sutra}
position: {count}
---
### मूल श्लोक :
```
{mool_shloka}

```

### Hindi Translation By Swami Ramsukhdas
```
{hindi_translation}

```

### Hindi Commentary By Swami Chinmayananda
```
{Commentary}

```

### English Translation By Swami  Sivananda
```
{english_translation}

```

'''
bookname = "srimad"
lang ="dv"


def main():
    ts = datetime.today() - timedelta(days=1)
    with open(bookname+".csv","r") as inpf:
        reader = csv.DictReader(inpf)
        for row in reader: 
            counter = row["counter"]
            nts = ts + timedelta(minutes=int(counter))
            #2019-04-21T21:21:19+01:00
            fnts = nts.replace(tzinfo=timezone.utc).isoformat()
            chapter = row["chapter"]
            sutra = row["sutra"]
            mool_shloka = row["mool_shloka"]
            hindi = row["hindi"]
            Commentary = row["Commentary"]
            english_translation = row["english_translation"]
            print(counter,chapter,sutra)
            writeToFile(counter,bookname,chapter,sutra,mool_shloka,hindi,Commentary,english_translation,fnts)

def crawl():
   
    total_chapters,sutras = getBookDetails(bookname,lang,1)
    print("Chapters = {chapters}".format(chapters=total_chapters))

    counter = 1
    for chapter in range(1,total_chapters+1):
        print(chapter)

        if not sutras:
            total_chapters,sutras = getBookDetails(bookname,lang,chapter)

        for sutra in range(1,sutras+1):

            print(chapter,sutra)
            mool_shloka,hindi_translation,Commentary,english_translation = getSutraContent(bookname,lang,chapter,sutra)
            writeToCsv(counter,bookname,chapter,sutra,mool_shloka,hindi_translation,Commentary,english_translation)
            counter = counter + 1
            # writeToFile(bookname,chapter,sutra,mool_shloka,hindi_translation)

            if sutra == sutras:
                sutras = None

def writeToCsv(counter,bookname,chapter,sutra,mool_shloka,hindi_translation,Commentary,english_translation):
    with open(bookname+".csv","a") as outf:
        writer = csv.writer(outf)
        if counter ==1:
            writer.writerow(["counter","chapter","sutra","mool_shloka","hindi","Commentary","english_translation"])
        writer.writerow([counter,chapter,sutra,mool_shloka,hindi_translation,Commentary,english_translation])

def writeToFile(counter,bookname,chapter,sutra,mool_shloka,hindi_translation,Commentary,english_translation,ts):
    path = "content/chapter-{chapter}".format(bookname=bookname,chapter=chapter)
    if not os.path.isdir(path):
        os.makedirs(path)

    with open(path + "/sutra-"+str(sutra) + ".md", 'w') as file_to_write:
        file_to_write.write(Template.format(
            count = counter,
            chapter = chapter,
            sutra = sutra,
            title="Verse: %s,%s"%(chapter,sutra),
            mool_shloka=mool_shloka.strip(),
            hindi_translation=hindi_translation.strip(),
            Commentary=Commentary.strip(),
            english_translation =english_translation.strip(),
            ts=ts))


def getSutraContent(bookname,lang,chapter,sutra):
    url = root.format(
        bookname = bookname,
        lang = lang,
        chapter = chapter,
        sutra = sutra
        )
    result = requests.get(url)
    if result.status_code == 200:
        c = result.content;
        soup = BeautifulSoup(c,'html.parser')
        fonts =  soup.select("font")# soup.select('div[class=custom_display_even]')
        lst = []
        for font in fonts:
            if font.attrs["size"] == "3px":
                lst.append(font)

        mool_shloka = ""
        hindi_translation = ""
        Commentary = ""
        english_translation = ""
        if len(lst) > 0:
            mool_shloka = lst[0].text
        if len(lst)  > 1:
            hindi_translation = lst[1].text
        if len(lst) > 2:
            Commentary = lst[2].text
        if len(lst) > 3:
            english_translation = lst[3].text
        return mool_shloka,hindi_translation,Commentary,english_translation
        

def getBookDetails(bookname,lang,chapter):
    url = root.format(
        bookname = bookname,
        lang = lang,
        chapter = chapter,
        sutra = 1
        )
    result = requests.get(url)
    
    if result.status_code == 200:
        c = result.content;
        soup = BeautifulSoup(c,'html.parser')
         
        chapterOptions = soup.select('select[id=edit-field-chapter-value] > option')
        sutraOptions = soup.select('select[id=edit-field-nsutra-value] > option') 

        chapters = [ int(o.text.strip()) for o in chapterOptions]
        sutras = [ int(o.text.strip()) for o in sutraOptions] 

        return max(chapters), max(sutras)
    else:
        return None,None

if __name__ == '__main__':
    main()