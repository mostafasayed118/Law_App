package com.legalhub.app

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // AGP 9 does not generate BuildConfig, so the debuggable flag is the
        // release/debug discriminator: release builds block screenshots and
        // recents thumbnails of matter/document/message content, while debug
        // builds stay screenshot-able for demos.
        val debuggable =
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!debuggable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
