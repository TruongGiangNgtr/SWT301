package com.swt301.datetimechecker;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONObject;

public final class MainActivity extends Activity {
    private EditText day, month, year, apiUrl;
    private TextView result;
    private Button check;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private int generation = 0;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        setContentView(R.layout.activity_main);
        day = findViewById(R.id.day); month = findViewById(R.id.month);
        year = findViewById(R.id.year); apiUrl = findViewById(R.id.api_url);
        result = findViewById(R.id.result); check = findViewById(R.id.check);
        check.setOnClickListener(v -> checkDate());
        findViewById(R.id.clear).setOnClickListener(v -> {
            generation++;
            day.setText(""); month.setText(""); year.setText(""); result.setText("");
            check.setEnabled(true);
        });
    }

    private void checkDate() {
        final JSONObject body = new JSONObject();
        final URI endpoint;
        try {
            body.put("day", Integer.parseInt(day.getText().toString()));
            body.put("month", Integer.parseInt(month.getText().toString()));
            body.put("year", Integer.parseInt(year.getText().toString()));
        } catch (Exception ex) { result.setText("Input data must be integers."); return; }
        try {
            String base = apiUrl.getText().toString();
            endpoint = URI.create(base + "/api/dates/check");
            String host = endpoint.getHost();
            if (!"http".equals(endpoint.getScheme()) ||
                !("10.0.2.2".equals(host) || "127.0.0.1".equals(host) || "localhost".equals(host)) ||
                endpoint.getPort() < 1 || endpoint.getUserInfo() != null)
                throw new IllegalArgumentException();
        } catch (Exception ex) { result.setText("Use a local API URL with an explicit port."); return; }
        final int version = ++generation;
        result.setText("Checking...");
        check.setEnabled(false);
        executor.execute(() -> {
            String message;
            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) endpoint.toURL().openConnection();
                connection.setInstanceFollowRedirects(false);
                connection.setRequestMethod("POST");
                connection.setConnectTimeout(5000); connection.setReadTimeout(5000);
                connection.setDoOutput(true);
                connection.setRequestProperty("Content-Type", "application/json");
                try (var stream = connection.getOutputStream()) {
                    stream.write(body.toString().getBytes(StandardCharsets.UTF_8));
                }
                int status = connection.getResponseCode();
                try (InputStream stream = status < 400 ? connection.getInputStream() : connection.getErrorStream()) {
                    if (stream == null) throw new IllegalStateException("No response");
                    java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
                    byte[] buffer = new byte[4096];
                    for (int count; (count = stream.read(buffer)) != -1;) bytes.write(buffer, 0, count);
                    JSONObject response = new JSONObject(bytes.toString(StandardCharsets.UTF_8.name()));
                    if (status == 200) message = response.getString("message");
                    else if (response.has("errors")) {
                        JSONObject errors = response.getJSONObject("errors");
                        String field = errors.has("day") ? "day" : errors.has("month") ? "month" : "year";
                        message = errors.getJSONArray(field).getString(0);
                    } else message = response.optString("title", "API error: " + status);
                }
            } catch (Exception ex) { message = "Cannot reach the local API."; }
            finally { if (connection != null) connection.disconnect(); }
            final String displayed = message;
            runOnUiThread(() -> {
                if (!isDestroyed() && generation == version) {
                    result.setText(displayed); check.setEnabled(true);
                }
            });
        });
    }

    @Override protected void onDestroy() {
        generation++;
        executor.shutdownNow();
        super.onDestroy();
    }
}
