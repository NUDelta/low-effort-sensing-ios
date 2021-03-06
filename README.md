# Low Effort Sensing
A platform for low-effort data collection on the iPhone and Apple Watch enabled by the 4X process.

# Related Repositories
1. [Backend](https://github.com/NUDelta/low-effort-sensing-backend): a Node.js and Parse Cloud backend that coordinates the collection and querying of data from users.
2. [Data Analysis](https://github.com/NUDelta/low-effort-sensing-analysis): a set of Jupter Notebooks for analyzing log data from previous studies.

# Installation
1. Make sure you have an iPhone with an Apple Watch paired to the phone.
2. Clone the repo and run `pod install`.
3. Open `low-effort-sensing.xcworkspace`.
4. Run application and wait for installation to complete
5. On iPhone, launch the Watch application and install the low-effort-sensing WatchKit App. Wait for app to install on Watch.

# Development
## Development on iOS
1. You will need 5 separate provisioning profiles to build on device (iPhone Application, Today Widget, Watch Application, Watch Extension, and Notification Extension). Please talk to either Kapil or Yongsung to obtain these.
2. Run the application.

# Enterprise Deployment
1. Make sure you have all 5 enterprise provisioning profiles iPhone Application, Today Widget, Watch Application, Watch Extension, and Notification Extension) and the NU enterprise deployment certificate. Please talk to either Kapil or Yongsung to obtain these.
2. Close Xcode and navigate to the local repository.
3. Run `chmod +x LES_Enterprise_export.sh` to make the shell script executable and then `./LES_Enterprise_export.sh` to execute. This will start cleaning, archiving, and exporting LES as an `.ipa` file.
4. Once the process is complete, the *.ipa* file can be found in **low-effort-sensing.ipa/low-effort-sensing.ipa**. To deploy to users, we recommend using [Diwai](https://www.diawi.com/).
