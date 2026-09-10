const baseUrl = "https://monecole-4jfb.onrender.com";
//const baseUrl = "http://127.0.0.1:8000";
//const baseUrl = "http://172.20.10.6:8000";

const String newsApiUrl = "$baseUrl/api/news/";
const String musicListUrl = "$baseUrl/api/music/songs/";

const String radioStreamUrl = "https://ec6.yesstreaming.net:2760/stream";
const String radioStreamUrl2 = "https://ec6.yesstreaming.net:2770/stream";

/// URL of the compiled Remote Flutter Widgets binary (`.rfw`) that drives
/// the in-app "Updates & Announcements" panel. Replace the file at this
/// URL on your server (compiled via `dart run tool/compile_rfw.dart`) to
/// change that panel's content without an App Store / Play Store release.
const String rfwUpdatesUrl = "https://app.radiomauritanie.mr/home.rfw";

/// Base URL of the station's YouTube channel, used to list its playlists
/// and latest uploaded videos in-app.
const String youtubeChannelUrl = "https://www.youtube.com/@radiomauritani";
