# KOReader Page Turner Companion App 


## Demo

https://github.com/user-attachments/assets/bd13a4a6-5d70-472a-961a-e4cc17735913

## Features

 - Frontlight Intensity and Warmth control
 - Nightmode Toggle
 - Full Screen Refresh
 - 5 custom profiles buttons that activate one of your custom profiles
 - Page Turning with the volume buttons and remapping capabilities
 - Navigate back and forward between pressed links, and a custom 'back' button
 - Text Input screen capable of getting, sending and clearing any text inside an input text widget in KOReader, especially useful to write notes from the comfort of your phone screen.
 - Reading Mode: immersive reading mode with minimal UI and minimal brightness. Contribution by [pleguen](https://github.com/pleguen)


## Install

* Go to releases and Download and install the [latest version](https://github.com/TomasDiLeo/koreader_pageturner_companion/releases/latest)
* In KOReader go to `Tools -> More Tools -> KOReader HTTP Inspector` and start the HTTP Server (Take note of the port, 8080 by default)
* In KOReader go to `Settings -> Network -> Network info` and take note of the network and ip
* In the Page Turner Companion app put the IP and PORT and press "CONNECT"
* Enjoy

## Troubleshooting 

|Problem|Try|
|-------|---|
|Profiles don't activate|Make sure the names are written exactly the same way. Check the `Show in action list` checkbox in the profile's settings|
|Can't connect to the KOReader device| Check the device's IP, they tend to change from time to time. Check that both devices are in the same network. Ensure that the HTTP Inspector plugin is running|


----
### Deprecated
For the dedicated KOReader plugin + companion go To [Page Turner Plugin](https://github.com/TomasDiLeo/pageturner.koplugin) for more details
