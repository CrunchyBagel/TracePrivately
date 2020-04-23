package com.example.traceprivately;

import androidx.appcompat.app.AppCompatActivity;

import android.app.PendingIntent;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;

import com.google.android.play.core.tasks.OnCompleteListener;
import com.google.android.play.core.tasks.OnFailureListener;
import com.google.android.play.core.tasks.OnSuccessListener;
import com.google.android.play.core.tasks.Task;

import java.util.List;

public class MainActivity extends AppCompatActivity implements View.OnClickListener, ContactTracing.ContactTracingCallback {

    ContactTracing tracing = new ContactTracing();

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

                Intent intent = new Intent(this, MainActivity.class);
                PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT);

                Task<ContactTracing.Status> task = this.tracing.startContactTracing(pendingIntent);

                task.addOnSuccessListener(new OnSuccessListener<ContactTracing.Status>() {
                    @Override
                    public void onSuccess(ContactTracing.Status result) {

                    }
                });

                task.addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(Exception e) {

                    }
                });

                task.addOnCompleteListener(new OnCompleteListener<ContactTracing.Status>() {
                    @Override
                    public void onComplete(Task<ContactTracing.Status> task) {

                    }
                });


            case R.id.button_stop_tracing:

                this.tracing.stopContactTracing();
                break;

            default:
                break;
        }
    }

    @Override
    public void onContact() {
        // TODO: Use getContactInformation() to get the info so it can be displayed
    }

    @Override
    public void requestUploadDailyTracingKeys(List<ContactTracing.DailyTracingKey> keys) {
        // TODO: Upload keys to server as this is only called after a positive diagnosis
    }

    @Override
    public void requestProvideDiagnosisKeys() {
        // TODO: Add all of the infected keys from the server here using provideDiagnosisKeys()
    }
}
