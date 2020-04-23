package com.example.traceprivately;

import androidx.appcompat.app.AppCompatActivity;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;

public class MainActivity extends AppCompatActivity implements View.OnClickListener {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Button startButton = (Button) findViewById(R.id.button_start_tracing);
        startButton.setOnClickListener(this);
        startButton.setVisibility(View.VISIBLE);

        Button stopButton = (Button) findViewById(R.id.button_stop_tracing);
        stopButton.setOnClickListener(this);
        stopButton.setVisibility(View.GONE);
    }


    @Override
    public void onClick(View v) {
        switch (v.getId()) {
            case R.id.button_start_tracing:
                break;
            case R.id.button_stop_tracing:
                break;
            default:
                break;
        }
    }
}
