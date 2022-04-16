---
layout: post
title:  "Backing up my saved articles"
date:   2022-04-14 13:48:00 +0100
tags: [dev", "instapaper", "reading"]
---

## What and why?

<br />I try to follow a lot of newsfeeds during a typical week. Most of these are of technical nature but I also enjoy some chess content as well. Typically I do not have enough time to dive deep into an article whenever I discover something interesting. Therefore I am a long time user of Instapaper, a read-it-later service you probably already have heard of. In the course of the last few years I saved multiple thousand articles there. When GDPR came around Instapaper was not accessible for a long time in Europe which led me to look around for different solutions. However none of the other solutions really did it for me (Pocket f.e) which is why I started to create my own project. Couple of years forward and I have multiple GitHub repositories with better and worse implementations of a read-it-later app. One of these implementations (Reading Time) even was available on the App Store for a couple of months but I realized that it was to much effort for me to maintain this app. 

<br />Meanwhile Instapaper became available in Europe again and I figured there wasn't an alternative I liked better. Since Instapaper has an export feature and I wanted to prevent to lose all my saved articles whenever Instapaper would close its doors I would regularly login to the Instapaper website, download a csv dump of my saved articles and persist this in a private GitHub repository of mine. This however was a cumbersome process to say the least. 

## The Solution

<br />So I knew I wanted to use Instapaper and I wanted to export my saved articles on a regular basis to make sure I wouldn't loose any of my link history. I figured GitHub Actions would be ideal to do exactly that and as a bonus are completely free. To create a GitHub action you need to create a new yaml configuration in `your-repo/.github/workflows/your-workflow-name.yml`. For me this looks like this:<br />

{% highlight yml %}
name: Instapaper Export

on:
  schedule:
    - cron: "0 0 * * *"
  workflow_dispatch:

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
    - name: Set up Python 3.9.12
      uses: actions/setup-python@v3
      with:
        python-version: "3.9.12"
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    - name: setup git config
      run: |
        git config user.name "David v.Knobelsdorff"
        git config user.email "youremail@email-address.com"
    - name: run export script
      run: |
        INSTAPAPER_PASSWORD=${{ secrets.INSTAPAPER_PASSWORD }} python export-instapaper.py --archive
    - name: commit
      run: |
        git add -A
        (git commit -m "update instapaper export" && git push origin master) || echo "No changes to commit"
{% endhighlight %}

<br />The cron parameter specifies that this action runs daily at midnight. To login into Instapaper I need my password which is passed via a secret environment variable. You can specifiy those in your repos settings. Last but not least the workflow runs my python script export-instapaper.py and pushes any changed files to remote.<br />

<br />GitHub Actions made this automation super simple and I highly recommend checking it out if you haven't. You even get an E-Mail notification if an action should fail.

## The actual script & archiving

<br />What is left is the implementation of the actual Script. Probably this is what you came for, right?
Without any further ado here it is:<br />

{% highlight python %}
#!/usr/bin/env python3

import logging
import sys
import json
import os
import argparse
import html
import requests
import keyring
import csv
import collections
import io
from html.parser import HTMLParser
from waybackpy import WaybackMachineSaveAPI

parser = argparse.ArgumentParser(description='export instapaper bookmarks')
parser.add_argument("--archive", action="store_true")
args = parser.parse_args()


class GetFormkeyParser(HTMLParser):
    def handle_starttag(self, tag, attrs):
        if tag == 'input':
            attrs = dict(attrs)
            if attrs.get('name') == 'form_key':
                self.form_key = attrs['value']

    @classmethod
    def get_form_key(cls, html):
        parser = cls()
        parser.feed(html)
        return parser.form_key


def export_instapaper(fmt='csv'):
    assert fmt in ('html', 'csv')

    s = requests.Session()
    username = 'your username'
    password = keyring.get_password('https://instapaper.com', username) or os.environ['INSTAPAPER_PASSWORD']

    if password is None:
        raise Exception("you need to set a password")

    req = s.post("https://www.instapaper.com/user/login",
                 data={'username': username,
                       'password': password})

    if req.status_code != 200:
        req.raise_for_status()

    req = s.get("https://www.instapaper.com/user")

    if req.status_code != 200:
        req.raise_for_status()

    form_key = GetFormkeyParser.get_form_key(req.content.decode('utf8'))

    req = s.post("https://www.instapaper.com/export/{}".format(fmt), data={'form_key':form_key})

    if req.status_code != 200:
        req.raise_for_status()

    return req.content.decode('utf8')

new_content = export_instapaper()

if args.archive:
    old_file = open('instapaper-export.csv', 'r')
    old = csv.DictReader(old_file)
    new = csv.DictReader(io.StringIO(new_content))

    old_urls = []
    new_urls = []

    for col in old:
        old_urls.append(col['URL'])

    for col in new:
        new_urls.append(col['URL'])

    urls_to_save = set(new_urls) - set(old_urls)
    user_agent = "Mozilla/5.0 (Windows NT 5.1; rv:40.0) Gecko/20100101 Firefox/40.0"

    for url in urls_to_save:
        print("Archiving {}".format(url))
        save_api = WaybackMachineSaveAPI(url, user_agent)
        save_api.save()

file = open('instapaper-export.csv', 'w')
file.write(new_content)
file.close()

html_file = open('instapaper-export.html', 'w')
html_file.write(export_instapaper(fmt='html'))
html_file.close()
{% endhighlight %}

<br />Basically this authenticates on the Instapaper website, grabs the form field "form_key" (some csrf token) and triggers the export endpoint via HTTP POST. 

<br />As a bonus I added a command line argument "archive". If present the script will compare the exported links to links exported previously. All newly added urls are saved to the [Internet Archive](https://archive.org) via the third-party library [waybackpy](https://github.com/akamhy/waybackpy). This way even if Instapaper shuts down I have a complete list of all articles I read or want to read and I will also find a snapshot of the website on the internet archive if one of the articles isn't reachable anymore.

Last but not least I also export all links in the HTML format Instapaper offers to maximize compatibility with other services (f.e Pocker only allows to import Instapaper articles from an HTML export).<br />
## Conclusion

<br />This script is running for a couple of days now and I had no trouble since. I am pretty happy with the workflow now and use Instapaper on a daily basis without worrying over loosing all my links or being unable to read an article because the website shut down or the article was deleted. If you want to try it yourself I am happy to hear from you. 
