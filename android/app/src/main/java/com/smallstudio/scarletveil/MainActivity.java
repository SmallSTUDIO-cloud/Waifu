package com.smallstudio.scarletveil;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.Locale;

/** Offline test wrapper: serves the built game from assets, never from a remote site. */
public final class MainActivity extends Activity {
    private static final String HOST = "appassets.androidplatform.net";
    private WebView game;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        immersive();
        game = new WebView(this);
        game.setBackgroundColor(0xff0c1116);
        WebSettings settings = game.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        game.setWebViewClient(new LocalAssetsClient());
        setContentView(game);
        game.loadUrl("https://" + HOST + "/index.html");
    }

    private void immersive() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }

    @Override public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (focused) immersive();
    }

    @Override protected void onPause() {
        if (game != null) {
            game.evaluateJavascript("if(document.getElementById('game') && !document.getElementById('game').classList.contains('hidden') && document.getElementById('overlay').classList.contains('hidden')) document.getElementById('pause').click()", null);
            game.onPause();
        }
        super.onPause();
    }

    @Override protected void onResume() {
        super.onResume();
        if (game != null) game.onResume();
    }

    @Override public void onBackPressed() {
        if (game == null) { super.onBackPressed(); return; }
        game.evaluateJavascript("(function(){var g=document.getElementById('game'); if(!g || g.classList.contains('hidden')) return false; if(document.getElementById('overlay').classList.contains('hidden')) document.getElementById('pause').click(); else document.getElementById('back').click(); return true;})()", handled -> {
            if ("false".equals(handled)) finish();
        });
    }

    @Override protected void onDestroy() {
        if (game != null) { game.destroy(); game = null; }
        super.onDestroy();
    }

    private final class LocalAssetsClient extends WebViewClient {
        @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            return !"https".equals(request.getUrl().getScheme()) || !HOST.equals(request.getUrl().getHost());
        }

        @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            if (!"https".equals(request.getUrl().getScheme()) || !HOST.equals(request.getUrl().getHost())) return missing();
            String path = request.getUrl().getPath();
            if (path == null || path.contains("..") || path.contains("\\")) return missing();
            if (path.equals("/")) path = "/index.html";
            try {
                InputStream stream = getAssets().open("web" + path);
                String name = path.toLowerCase(Locale.ROOT);
                String mime = name.endsWith(".html") ? "text/html" : name.endsWith(".js") ? "text/javascript" :
                    name.endsWith(".css") ? "text/css" : name.endsWith(".png") ? "image/png" :
                    name.endsWith(".jpg") || name.endsWith(".jpeg") ? "image/jpeg" : "application/octet-stream";
                return new WebResourceResponse(mime, mime.startsWith("text/") ? "UTF-8" : null, stream);
            } catch (IOException ex) { return missing(); }
        }

        private WebResourceResponse missing() {
            return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
        }
    }
}
