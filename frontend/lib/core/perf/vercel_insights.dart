// Vercel's Speed Insights and Web Analytics scripts on the web app (the
// browser's own numbers, in the owner's Vercel dashboard): loaded once the
// app's start is in, only on a build with a commit (the live app). Nothing
// elsewhere.
export 'vercel_insights_stub.dart'
    if (dart.library.js_interop) 'vercel_insights_web.dart';
