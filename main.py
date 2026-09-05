# `requests` and `bs4` are imported inside the two functions that scrape, not
# here. Regenerating `content/` from `srimad.csv` is the offline path everyone
# actually runs, and it has no business failing on a checkout that has not
# installed a network stack it never uses.
import os
import sys
import csv
import json
import sqlite3
from datetime import datetime, timedelta,timezone

# The shloka and the IAST need two repairs before they are fit to print, and
# both already exist — in `tools/build_db.py`, which does them for the app.
# Imported rather than copied: this is the only thing that keeps the site and
# the app saying the same words. `build_db` guards its own entry point, so
# importing it runs nothing.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
from build_db import (normalize as normalizeShloka, align_transliteration,
                      strip_reference)

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
{{{{< lines >}}}}
{mool_shloka}
{{{{< /lines >}}}}

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
        SELECT chapter, sutra, sanskrit, transliteration,
               hindi_translation, english_translation,
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

    # Aligned against the *normalised* shloka, which is what the page prints
    # and what the app aligns against — against the raw one the line counts
    # differ and the repair declines to act.
    translit = align_transliteration(normalizeShloka(row["sanskrit"] or ""),
                                     row["transliteration"])
    translit = (translit or "").strip()
    if translit:
        blocks.append("### Transliteration\n{{< lines >}}\n%s\n{{< /lines >}}" % translit)

    hindi_translation = (row["hindi_translation"] or "").strip()
    if hindi_translation:
        blocks.append("### अनुवाद\n\n%s" % hindi_translation)

    hindi_meaning = (row["hindi_meaning"] or "").strip()
    if hindi_meaning:
        blocks.append("### भावार्थ\n\n%s" % hindi_meaning)

    english_translation = (row["english_translation"] or "").strip()
    if english_translation:
        blocks.append("### Translation\n\n%s" % english_translation)

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

    # The database wins wherever it holds the same field.
    #
    # `srimad.csv` is the scrape as it came off the Supersite, and it carries
    # the page's own furniture with it: the shloka's two lines run together
    # around a danda, and every translation opens with the reference it was
    # printed under — "।।5.27  5.28।।" ahead of the words themselves. The
    # enriched rows are the same text cleaned up, with the lines separated and
    # the markers gone, and they are what the app reads. Two sources for one
    # verse means the site and the app can disagree about what it says; this
    # settles which one is right.
    #
    # Field by field, not row by row: the commentary exists only in the CSV,
    # and a verse the enrichment has not reached still gets everything the
    # scrape had.
    # The database's `hindi_translation` and `english_translation` are not
    # cleaned-up copies of the scraped ones — they are the enrichment's own
    # renderings. So they are added *beside* the scraped ones rather than over
    # them, under अनुवाद and Translation, where nothing is attributed to
    # anyone; the headings naming Swami Ramsukhdas and Swami Sivananda keep
    # standing over the words those two actually wrote. Replacing the text
    # under a heading that credits someone else is the one thing that would be
    # wrong here, and it is the only thing this does not do.
    #
    # The Sanskrit is a different case: same words, better kept. The scrape
    # runs the two lines together around a danda and ends with the reference
    # printed on the page — "।।5.28।।" — which is the Supersite's furniture
    # rather than the verse.
    # Through `build_db.normalize`, not merely copied. The stored Sanskrit
    # still runs the speaker's name into the first word of what they say —
    # "श्री भगवानुवाचकुतस्त्वा" — because sandhi swallows the उ of उवाच into a
    # combining sign, so nothing that searches for the word can find it. That
    # is fixed once, in the app's builder, for the 28 verses it affects; the
    # site was printing them glued together.
    if enrichedRow is not None:
        mool_shloka = normalizeShloka(enrichedRow["sanskrit"] or "") or mool_shloka

    with open(filename, 'w') as file_to_write:
        file_to_write.write(Template.format(
            count = counter,
            chapter = chapter,
            sutra = sutra,
            title="Verse: %s,%s"%(chapter,sutra),
            mool_shloka=mool_shloka.strip(),
            # The Supersite prints the reference above the words and the scrape
            # brought it along, so every translation on the site opened
            # "।।2.47।।कर्तव्यकर्म करनेमें…" — its page furniture, standing in
            # front of the sentence in a different script from it.
            hindi_translation=strip_reference(hindi_translation),
            Commentary=strip_reference(Commentary),
            english_translation=strip_reference(english_translation),
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