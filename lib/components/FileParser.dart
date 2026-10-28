import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_health_monitor/l10n/app_localizations.dart';

typedef RecordingMetadata = ({
  String filePath,
  String user,
  String lungName,
  int placement,
  int timeRecorded
});

class FileParser {
  static String encode(String input) {
    return input.replaceAll(":", "_").replaceAll(".", "?");
  }

  static String decode(String input) {
    return input
        .replaceAll("_", ":")
        .replaceAll("?", ".")
        .replaceAll(RegExp(r"\.(m4a|wav)$"), "");
  }

  static DateTime? toDateObject(String input) {
    var decoded = decode(input);

    var baseName = basename(input);
    var split = baseName.split("-");

    split.removeAt(0);
    var date = split
        .join("-")
        .replaceAll(RegExp(r"\.(m4a|wav)$"), "")
        .replaceAll("?", ".")
        .replaceAll("_", ":");

    var dateObject = DateTime.tryParse(date);

    return dateObject;
  }

  static String toDisplayString(String input, AppLocalizations localization) {
    var nameMappings = {
      "FrontLungs": localization.frontLungs,
      "BackLungs": localization.backLungs,
    };

    var baseName = basename(input);
    var split = baseName.split("-");
    var name = split[0];

    var dateObject = toDateObject(input);

    if (dateObject == null) {
      return "";
    }

    for (var key in nameMappings.keys) {
      var translation = nameMappings[key]!;
      name = name.replaceAll(key, translation);
    }

    return "(${dateObject.day}/${dateObject.month}/${dateObject.year}) $name";
  }

  static Future<String> getUserFolder(String user) async {
    var perms = await Permission.storage.status;
    if (perms.isDenied) {
      await Permission.storage.request();
    }
    var downloads = await getApplicationDocumentsDirectory();
    var recordingFolder = Directory("${downloads.path}/Recordings");
    if (!await recordingFolder.exists()) {
      await recordingFolder.create();
    }
    var userFolder = Directory(recordingFolder.path + "/" + user);
    if (!await userFolder.exists()) {
      await userFolder.create();
    }

    return userFolder.path;
  }

  // Target path is "user/lungname-placement_milliseconds"
  static Future<String> GetLungFilePath(String user, String lungName, String placement) async {
    var time = DateTime.now().millisecondsSinceEpoch;
    var fileName = "$lungName-${placement}_$time";
    var path = "${await getUserFolder(user)}/$fileName";

    return path;
  }

  static Future<List<FileSystemEntity>> GetRecordingsForUser(String user) async {
    var userFolder = Directory(await getUserFolder(user));
    var fsEntities = userFolder.listSync();
    var files = fsEntities.where((ent) {
      return FileSystemEntity.isFileSync(ent.path);
    });
    return files.toList();
  }

  static RecordingMetadata? GetRecordingMetadata(String filePath) {
    var pattern = RegExp(r"^(?<user>.*?)\/(?<lungName>.*?)-(?<placement>.*?)_(?<time>[0-9]*?)$");
    var result = pattern.firstMatch(filePath);
    if (result == null) {
      return null;
    }

    return (
      user: result.namedGroup("name")!,
      lungName: result.namedGroup("lungName")!,
      placement: int.parse(result.namedGroup("placement")!),
      timeRecorded: int.parse(result.namedGroup("time")!),
      filePath: filePath
    );
  }
}
