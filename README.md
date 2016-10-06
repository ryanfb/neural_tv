# neural_tv

This is the source code for the [Neural TV Twitter Bot](https://twitter.com/neural_tv), a bot that watches TV and tweets what it sees using a recurrent neural network for captioning images. The bot assumes a (working) copy of [neuraltalk2](https://github.com/karpathy/neuraltalk2) is in the `neuraltalk2/` subdirectory, alongside the unzipped [pretrained checkpoint model](http://cs.stanford.edu/people/karpathy/neuraltalk2/checkpoint_v1.zip).

* `hdhomerun-screenshot.rb` - finds an HDHomeRun on the local network and captures frames from a random channel
* `neuraltv.rb` - takes the captures and tweets a random result

Config variables (like Twitter auth keys) are outside version control in `.secrets.json`. Since I run the HDHomeRun capture and captioning processes on different machines, I use a shared directory to hold the images.

There are two main ways to control the feel of the bot: what you feed it, and what you let it tweet. Initially, I ran a single frame capture every minute, then every five minutes had it tweet a random result and start over. That got slightly repetitive, so now I have the bot keep a list of what it's tweeted (`neuraltv-utterances.txt`) and always try to tweet something new. I also increased the number of frames output from each run of the HDHomeRun capture process to increase the chances of it seeing something new. I also set up a channel blacklist that I can change over time, and some code for restricting the capture process to a single channel when I want to.
