import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_monitor/components/buttons.dart';
import 'package:smart_health_monitor/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MyHomePage();
  }
}

class _MyHomePage extends State<MyHomePage> {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  String? username;
  String? email;

  Future<void> getUserData() async {
    var prefs = await SharedPreferences.getInstance();

    username = prefs.getString("name");
    email = prefs.getString("email");
  }

  Future<void> logout() async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.remove("name");
    await prefs.remove("email");

    setState(() {
      username = null;
      email = null;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final imgStr = localizations.localeName == "id" ? "assets/app_id.jpg" : "assets/app_en.jpg";
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.appName,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: Colors.white,
      drawer: Drawer(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder(
                future: getUserData(),
                builder: (context, snapshot) {
                  if (username != null && email != null) {
                    return UserAccountsDrawerHeader(
                      accountEmail: Text(email!),
                      accountName: Text(username!),
                      currentAccountPicture: Image(
                        image: AssetImage("assets/profile_blank.png"),
                      ),
                    );
                  } else {
                    return SizedBox(
                      width: double.infinity,
                      child: DrawerHeader(
                        decoration: BoxDecoration(color: Colors.teal),
                        child: Image(image: AssetImage("assets/indonesia.jpg")),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.info),
                title: Text("About"),
                onTap: () {
                  Navigator.of(context).pushNamed("/about", arguments: "About");
                },
              ),
              ListTile(leading: Icon(Icons.feedback), title: Text("Feedback"), onTap: () => launchUrl(Uri.parse("https://wa.me/628123989134")),),
              ListTile(leading: Icon(Icons.chat), title: Text("Chatbot"), onTap: () => launchUrl(Uri.parse("https://wa.me/628983138381?text=.ai hi")),),
              ListTile(leading: Icon(Icons.chat), title: Text("Testimony"), onTap: () => launchUrl(Uri.parse("https://forms.gle/mtPVXBSVgn7Ma2EYA")),),
              ListTile(
                leading: Icon(Icons.group),
                title: Text("Testimonies"),
                onTap: () {
                  Navigator.of(
                    context,
                  ).pushNamed("/about", arguments: "Testimonies");
                },
              ),
              Spacer(),
              ListTile(
                leading: Icon(Icons.login),
                title: Text(username == null ? "Login" : "Logout"),
                onTap: () {
                  if (username == null) {
                    Navigator.of(context)
                        .pushNamed("/login")
                        .then(
                          (data) =>
                              getUserData().then((data) => setState(() {})),
                        );
                  } else {
                    logout();
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Image(image: AssetImage(imgStr)),
          ),
          DecoratedImageButton(
            text: AppLocalizations.of(context)!.diagnose,
            icon: "assets/diagnose.webp",
            onPressed: () => Navigator.pushNamed(context, "/diagnose"),
            color: Colors.red,
          ),
          DecoratedImageButton(
            text: AppLocalizations.of(context)!.storage,
            icon: "assets/folder.png",
            onPressed: () => Navigator.pushNamed(context, "/storage"),
            color: Colors.orange,
          ),
          DecoratedImageButton(
            text: AppLocalizations.of(context)!.bmiCalculator,
            icon: "assets/bmi.png",
            onPressed: () => Navigator.pushNamed(context, "/bmi"),
            color: Colors.blue,
          ),
          DecoratedImageButton(
            text: AppLocalizations.of(context)!.healthyLiving,
            icon: "assets/health_diet.png",
            onPressed: () => Navigator.pushNamed(context, "/lifestyle"),
            color: Colors.green,
          ),
          Text("Using language : ${Localizations.localeOf(context)}"),
        ],
      ),
    );
  }
}
