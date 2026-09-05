# `requests` and `bs4` are imported inside the two functions that scrape, not
# here. Regenerating `content/` from `srimad.csv` is the offline path everyone
# actually runs, and it has no business failing on a checkout that has not
# installed a network stack it never uses.
import os
import csv
import json
import sqlite3
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
{enriched}
'''

# Everything below the four scraped sections comes from `enriched.sqlite`,
# which is what the app reads too — so a verse page on the site now carries the
# same things the app puts in front of a reader: the transliteration, the
# meaning in both languages, and every Sanskrit word glossed.
#
# Built as one block rather than as more `{}` placeholders in the template
# above, because a verse the enrichment has not reached should print nothing
# here at all rather than a run of empty headings.
ENRICHED_DB = "enriched.sqlite"


def loadEnriched():
    """Every enriched verse, keyed by (chapter, sutra).

    Returns an empty dict if the database is absent, so `main()` still
    regenerates the four scraped sections on a checkout that has not built it.
    """
    if not os.path.exists(ENRICHED_DB):
        print("note: %s not found — writing the scraped sections only" % ENRICHED_DB)
        return {}

    rows = {}
    db = sqlite3.connect(ENRICHED_DB)
    db.row_factory = sqlite3.Row
    for row in db.execute("""
        SELECT chapter, sutra, transliteration,
               hindi_meaning, english_meaning,
               word_by_word_hindi, word_by_word_english
        FROM enriched_verses
    """):
        rows[(int(row["chapter"]), int(row["sutra"]))] = row
    db.close()
    return rows


def glossTable(payload, wordHeading, meaningHeading):
    """A word-by-word list as a Markdown table.

    A table rather than a code fence: these are pairs, and a pair is what a
    table is for — it reads as two columns to a person and as a table to a
    screen reader, where a fenced block reads as one long line of preformatted
    text. The site's CSS styles `.verse-page table` for the same reason.
    """
    try:
        pairs = json.loads(payload or "[]")
    except (ValueError, TypeError):
        return ""

    if not pairs:
        return ""

    lines = ["| %s | %s |" % (wordHeading, meaningHeading), "| --- | --- |"]
    for pair in pairs:
        word = str(pair.get("w", "")).replace("|", "\\|").strip()
        meaning = str(pair.get("m", "")).replace("|", "\\|").strip()
        if word:
            lines.append("| %s | %s |" % (word, meaning))
    return "\n".join(lines)


def enrichedSections(row):
    """The app's own sections, in the app's own order, as Markdown."""
    if row is None:
        return ""

    blocks = []

    translit = (row["transliteration"] or "").strip()
    if translit:
        blocks.append("### Transliteration\n```\n%s\n\n```" % translit)

    hindi_meaning = (row["hindi_meaning"] or "").strip()
    if hindi_meaning:
        blocks.append("### भावार्थ\n\n%s" % hindi_meaning)

    english_meaning = (row["english_meaning"] or "").strip()
    if english_meaning:
        blocks.append("### Meaning\n\n%s" % english_meaning)

    hindi_words = glossTable(row["word_by_word_hindi"], "शब्द", "अर्थ")
    if hindi_words:
        blocks.append("### शब्दार्थ\n\n%s" % hindi_words)

    english_words = glossTable(row["word_by_word_english"], "Word", "Meaning")
    if english_words:
        blocks.append("### Word by word\n\n%s" % english_words)

    return ("\n\n" + "\n\n".join(blocks) + "\n") if blocks else ""

bookname = "srimad"
lang ="dv"


def main():
    ts = datetime.today() - timedelta(days=1)
    enriched = loadEnriched()
    print("enriched verses available: %d" % len(enriched))
    with open(bookname+".csv","r") as inpf:
        reader = csv.DictReader(inpf)
        for row in reader: 
            counter = row["counter"]
            nts = ts + timedelta(minutes=int(counter))
            fnts = nts.replace(tzinfo=timezone.utc).isoformat()
            chapter = row["chapter"]
            sutra = row["sutra"]
            mool_shloka = row["mool_shloka"]
            hindi = row["hindi"]
            Commentary = row["Commentary"]
            english_translation = row["english_translation"]
            print(counter,chapter,sutra)
            extra = enriched.get((int(chapter), int(sutra)))
            writeToFile(counter,bookname,chapter,sutra,mool_shloka,hindi,Commentary,english_translation,fnts,extra)

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

def existingDate(filename):
    """The `date:` a verse page already carries, if it has one.

    Regeneration used to stamp every page with today's date, so running the
    generator to add a section re-dated all 701 pages — which is a lie to the
    feed, the sitemap and anything reading `<meta>` dates, and 701 lines of
    noise in a diff whose real change is elsewhere. A verse's date is the day
    its page was first written; nothing since has changed the verse.
    """
    try:
        with open(filename, "r") as existing:
            for line in existing:
                if line.startswith("date: "):
                    return line[len("date: "):].strip()
                if line.startswith("### "):
                    break
    except IOError:
        pass
    return None


def writeToFile(counter,bookname,chapter,sutra,mool_shloka,hindi_translation,Commentary,english_translation,ts,enrichedRow=None):
    path = "content/chapter-{chapter}".format(bookname=bookname,chapter=chapter)
    if not os.path.isdir(path):
        os.makedirs(path)

    filename = path + "/sutra-" + str(sutra) + ".md"
    ts = existingDate(filename) or ts

    with open(filename, 'w') as file_to_write:
        file_to_write.write(Template.format(
            count = counter,
            chapter = chapter,
            sutra = sutra,
            title="Verse: %s,%s"%(chapter,sutra),
            mool_shloka=mool_shloka.strip(),
            hindi_translation=hindi_translation.strip(),
            Commentary=Commentary.strip(),
            english_translation =english_translation.strip(),
            enriched=enrichedSections(enrichedRow),
            ts=ts))


def getSutraContent(bookname,lang,chapter,sutra):
    url = root.format(
        bookname = bookname,
        lang = lang,
        chapter = chapter,
        sutra = sutra
        )
    import requests
    result = requests.get(url)
    if result.status_code == 200:
        c = result.content;
        from bs4 import BeautifulSoup
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
    import requests
    result = requests.get(url)
    
    if result.status_code == 200:
        c = result.content;
        from bs4 import BeautifulSoup
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