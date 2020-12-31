---
layout: post
title:  "Generating licenses for SPM dependencies"
date:   2020-12-24 22:15:00 +0100
tags: ["swift", "dev"]
---

# Generating licenses for SPM dependencies

Chances are your are using Swift Package Manager, at least to some degree, in your (i(Pad)?\|mac\|tv\|watch)OS app. Since the first class support in Xcode was added it definetly is my favourite tool to handle dependencies for apps in the Apple ecosystem.

As app developers we have to deal with a lot of stuff besides the actual development of features like setting up CI, supporting our customers etc. If you happen to use third party dependencies one of these tasks probably will be to include various Open Source licenses in your application. Having used well known alternatives like Carthage and Cocoapods before SPM was a thing I encountered plugins for these tools to automate this for me. Not only is this approach keeping work from me for every new project I fire up in Xcode, it also won’t forget to include a license for every dependency that is added. I can’t say that confidently about myself.

To avoid copying each license html manually like an animal I did a quick search for available tools for SPM and I found some. But none of them fitted my requirements exactly. Here is a list of possibilities for you:

- [Tribute](https://github.com/nicklockwood/Tribute)
- [LicensePlist](https://github.com/mono0926/LicensePlist)
- [LicenseGenerator-iOS](https://github.com/carloe/LicenseGenerator-iOS)

<br />Since I couldn’t find a perfect solution to my problem I thought it would be a fun exercise to build a tool by myself. Also, to be honest, it was a great excuse to get my hands on the recently released [swift-argument-parser](https://github.com/apple/swift-argument-parser). You can find the project on GitHub, it’s called [SPMLicenses](https://github.com/dehlen/SPMLicenses).

To set some expectations upfront: It hardly is a v1.0.0. I used it in two projects of mine now and it worked fine for me but I can‘t promise to build a full featured tool out of this. On the other hand it is Open Source so if there is something missing or not working for you spin up Xcode and a debugger and build a tool that fits your needs.

How does it work? SPMLicenses fetches all your third party dependencies from a Package.resolved file which is created and updated by Xcode. It further tries to find the GitHub url of the dependencies and fetches the license from the GitHub API. The result will then be written to a json file. There are at least two problems with this approach:

1. If you use packages which aren’t hosted on GitHub they won‘t be included in the json
2. You can get rate limited (60 requests per hour) for making to many API requests when running this on CI f.e

<br />No 2. is addressed by the fact that you can specify GitHub credentials when generating your license json. This way you won‘t get rate limited that easily (5000 requests per hour). It also makes sure you can access private repositories to fetch their licenses.
To register a GitHub application please follow this link: [https://github.com/settings/developers](https://github.com/settings/developers).

There are ideas to fix No 1. but as I said above: it hardly is a v1.0.0. For my current use case limiting the tool to GitHub only is totally fine. If you need something different I highly recommend using [Tribute](https://github.com/nicklockwood/Tribute) from Nick Lockwood. It definitely seems like the tool I want to use but unfortunately it is lacking SPM support at the time of this writing.

All of the above is expressed by a single call on your command line:
{% highlight sh %}
$ swift run spm-licenses <path to .xcworkspace> <output.json> <optional GitHub client id> <optional GitHub client secret>
{% endhighlight %}

<br />If you want to tinker with it or use the tool in one of your applications you can build SPMLicenses from source like so:
{% highlight sh %}
$ swift build -c release
$ cd .build/release
$ cp -f spm-licenses /usr/local/bin/spm-licenses
{% endhighlight %}

<br />Or use [Mint](https://github.com/yonaskolb/Mint):
{% highlight sh %}
$ mint install dehlen/SPMLicenses
{% endhighlight %}

<br />If you want to update the license file on every Xcode build you can add this simple script as a Run Script Build Phase. To set this up in Xcode, do the following:
1. Click on your project in the file list, choose your target under TARGETS, click the Build Phases tab
2. Add a New Run Script Phase by clicking the little plus icon in the top left and paste in the following script:

<br />
{% highlight sh %}
if which spm-licenses >/dev/null; then
 spm-licenses <path to .xcworkspace> <output.json> <optional GitHub client id> <optional GitHub client secret>
else
  echo "warning: SPMLicenses not installed, download from https://github.com/dehlen/SPMLicenses"
fi
{% endhighlight %}

<br />To wrap things up you can use this SwiftUI module to automatically render the generated licenses in your app:
{% highlight swift %}
import Foundation
import SwiftUI
import os

struct License: Codable, Identifiable {
    let licenseName: String
    let licenseText: String
    let packageName: String
    
    var id: String { packageName }
}

extension License {
    static let mock: License = .init(licenseName: "MIT", licenseText: "MIT license text", packageName: "Test Dependency")
}

final class LicensesViewModel: ObservableObject {
    @Published private(set) var licenses: [License] = []
    #warning("update subsystem string")
    private let logger = Logger(subsystem: "com.sample.app", category: String(describing: LicensesViewModel.self))

    init() {
        #warning("make sure licenses.json is added to the project")
        guard let url = Bundle.main.url(forResource: "licenses", withExtension: "json") else {
            logger.debug("Could not read licenses because file does not exist.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            self.licenses = try JSONDecoder().decode([License].self, from: data)
        } catch {
            logger.debug("Could not read licenses: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct LicensesView: View {
    @ObservedObject var viewModel: LicensesViewModel

    var body: some View {
        List(viewModel.licenses) { license in
            LicenseView(license: license)
        }.navigationBarTitle(Text("Licenses"), displayMode: .inline)
    }
}

struct LicensesView_Previews: PreviewProvider {
    static var previews: some View {
        LicensesView(viewModel: .init())
    }
}

struct LicenseView: View {
    let license: License
    var body: some View {
        NavigationLink(destination: LicenseDetailView(license: license)) {
            HStack {
                Text(license.packageName)
                    .font(.body)
                Spacer()
                Text(license.licenseName)
                    .font(.body)
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
    }
}

struct LicenseView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseView(license: .mock)
    }
}

struct LicenseDetailView: View {
    let license: License
    
    var body: some View {
        ScrollView {
            VStack {
                Text(license.licenseText)
                Spacer()
            }.padding()
        }.navigationBarTitle(Text(license.packageName), displayMode: .inline)
    }
}

struct LicenseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseDetailView(license: .mock)
    }
}
{% endhighlight %}
