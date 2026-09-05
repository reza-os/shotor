set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get
flutter build apk --release

از دستورات بالا هنگامی که flutter run -d کار نمیکنه استفاده کن

------------------------------------------------------------------------------------------------------------

برای ایجاد شاخه fixmapp روی شاخه fixmap از دستور زیر استفاده کردم
یعنی شاخه جدید درست کردم و بعد merge کردم

If you like the method in the link you've posted, have a look at Git Flow.

It's a set of scripts he created for that workflow.

But to answer your question:

git checkout -b myFeature dev
Creates the myFeature branch off dev. Do your work and then
-
git commit -am "Your message"
Now merge your changes to dev without a fast-forward
-
git checkout dev
git merge --no-ff myFeature
Now push the changes to the server
-
git push origin dev
-
git push origin myFeature
-
And you'll see it how you want it.