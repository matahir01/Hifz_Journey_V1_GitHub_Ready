$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Jar = Join-Path $Root "android\gradle\wrapper\gradle-wrapper.jar"
$Gradlew = Join-Path $Root "android\gradlew"
if ((Test-Path $Jar) -and (Test-Path $Gradlew)) { exit 0 }
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("hifz-bootstrap-" + [guid]::NewGuid())
flutter create --platforms=android --project-name hifz_journey --org com.hifzjourney $Temp | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root "android\gradle\wrapper") | Out-Null
Copy-Item (Join-Path $Temp "android\gradlew") (Join-Path $Root "android\gradlew") -Force
Copy-Item (Join-Path $Temp "android\gradlew.bat") (Join-Path $Root "android\gradlew.bat") -Force
Copy-Item (Join-Path $Temp "android\gradle\wrapper\gradle-wrapper.jar") $Jar -Force
@"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@ | Set-Content (Join-Path $Root "android\gradle\wrapper\gradle-wrapper.properties")
Remove-Item $Temp -Recurse -Force
