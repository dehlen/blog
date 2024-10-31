---
color: C07309
date: 2024-10-31T17:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (9/9): Testing and Conclusion
category: swift
slug: writing-a-chess-app-9-9-testing-and-conclusion
---

## Unit Tests

Well you probably think now "Isn't this a personal project? Why bother writing unit tests?" I actually found a lot of joy writing unit tests for this project. Since I basically have no third-party dependencies, no network traffic, etc. there isn't really much to mock or stub. The unit tests do what they are best at: Testing a logical unit of code and making sure it behaves the way it should. With the unit tests in place I feel very confident to refactor and iterate on the various implemented algorithms and logic. I actually found that for the PGN parser and chess logic packages test driven development was quite fun and helpful in making my implementation correct. For the future I plan to have a look at the new[ swift-testing](https://developer.apple.com/xcode/swift-testing/) framework. 

## That's a wrap

You probably already got the impression that I am pretty passionate about chess and software development. This project really helped me finding joy again in writing software for my own personal use. What I especially liked about this project is that it was totally different from my typical "side project". Most of the time I repeat the same boilerplate code, requesting some API endpoints and displaying data in some form of a list. This time it was and still is all about performance, reading up on algorithms, creating some custom UI components. So I couldn't be happier I pulled through this time and can actually hold a useful product in my hands which I am very keen to iterate on in the upcoming months.

Despite all the positive experiences with this project there is one downside I found rather funny:  I am spending more time in Xcode and less time on [lichess](https://lichess.org) (Lichess is a charity and a free, libre, no-ads, open source chess server) actually playing chess. I guess there is only a limited amount of time in a day but I am looking forward to getting back at improving my chess skills now with my own little chess companion in my pocket.

If you liked this article, want to talk about chess or software development let me know!