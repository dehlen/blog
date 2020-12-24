layout: post
title:  "When your macOS application is about to quit"
date:   2020-05-01 10:13:00 +0100
categories: swift, dev, macOS
---

## Executing work before the application quits

A quick Google search on `NSApplication.TerminateReply` results in 328 results. I can't think of many search phrases which perform worse.
![Google Search](/NSApplication-TerminateReply-Google-Search.png)

In my Text Editor *Caret* I am not able to use Apples `NSDocument` class, or at least, I found, it probably isn't the best idea for my use case. However `NSDocument` comes with a neat little feature I knew I needed to support: **Autosaving changes**. Whenever a user edits text in the text editor the changes should be reflected on disk. Of course I do everything to coordinate these file changes and to have a reliable mechanism but to be extra sure I wanted to save all pending file changes before the application quits. Turns out this is what `NSApplication.TerminateReply` is for.

### Info.plist setup

First you most certainly want to set the following key in your `Info.plist`:

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSSupportsSuddenTermination</key>
	<false/>
</dict>
</plist>
{% endhighlight %}

Otherwise it can happen that `applicationShouldTerminate` won't being called and `NSApplicationWillTerminateNotification` won't being sent. With that out of our mind let's dive into using the above API.


### AppDelegate implementation
You might start by doing all your saving logic in 

{% highlight swift %}
func applicationWillTerminate(_ aNotification: Notification) {
  // Insert code here to tear down your application
} 
{% endhighlight %}

Unfortunately this won't work since, after all, the application will terminate. If your operation is taking enough time to finish you'll end up with a terminated process and no saved changes.

To fix this we need to implement `applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply`.
`NSApplication.TerminateReply` actually is an enum and can either be: 
* terminateCancel
* terminateNow
* terminateLater

`terminateCancel` will stop the termination of the application. This isn't a pleasant user experience since the user wanted to quit you app. Interesting however is `terminateNow` and `terminateLater`. When you do not have any pending file changes you can quit right away by returning `terminateNow`, but when you do have changes `terminateLater` is what you want.

Start by implementing something like the following logic in your AppDelegate:

{% highlight swift %}
func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
	if hasPendingChanges {
	  savePendingChanges()
		return .terminateLater
	}

	return .terminateNow
}
{% endhighlight %}

When you run your app in this state and quit it with pending changes the application won't be terminated. Whats left is to tell the process when you actually finished your save operation in order to terminate the application.
Luckily for us there is API to do exactly that: `NSApp.reply(toApplicationShouldTerminate: true)`.

To round things up this is how your `savePendingChanges` method should look like:

{% highlight swift %}
func savePendingChanges() {
	doSomeWork()
	NSApp.reply(toApplicationShouldTerminate: true)
}
{% endhighlight %}

### Conclusion
Doing work just before the application quits actually is pretty straightforward to implement on macOS. One common pitfall is to miss the Info.plist entry I mentioned at the beginning of the post. Of course, just because this option exists, you probably do not want to run operations which take a long time. This inevitably will lead to bad UX for your customers. Try to save as often as you can without sacrificing performance or user experience of your application. By implementing the pattern explained in this blog post you will make sure to provide a reliable experience for your users.
