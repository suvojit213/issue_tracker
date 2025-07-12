package com.suvojeet.issue_tracker_app

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
import kotlin.random.Random

class NotificationWorker(appContext: Context, workerParams: WorkerParameters) : Worker(appContext, workerParams) {

    private val messages = listOf(
        "Login and logout time pe, tagging miss pe, wifi off,system off,system hang, voice issue pe, Tagging missing pe issue tracker real time pe fill hona chahiye.",
        "Team one more important update ek sec bhi agar app ki voice na jaye ya observe ho ki headphone issue or system issue hai real time me issue tracker fill hona chahiye",
        "Kya apko system issue hua hai ?  ya CX voice break please fill issue tracker",
        "Don't be lazy to fill issue tracker it's for our safe side",
        "Kuch bhi issue aa raha hai\nFill issue Tracker on Real time\nCx ki awaj nhi aa rahi hai call par\nFill issue Tracker"
    )

    override fun doWork(): Result {
        val randomMessage = messages[Random.nextInt(messages.size)]
        NotificationHelper.showNotification(applicationContext, "Issue Tracker Reminder", randomMessage)
        NotificationHelper.saveNotificationToHistory(applicationContext, randomMessage)

        // Schedule the next notification
        scheduleNextNotification(applicationContext)

        return Result.success()
    }

    companion object {
        fun scheduleNextNotification(context: Context) {
            val minDelayMinutes = 45
            val maxDelayMinutes = 15 * 60 // 15 hours for 15 notifications a day, roughly
            val randomDelay = Random.nextLong(minDelayMinutes.toLong(), maxDelayMinutes.toLong())

            val notificationWorkRequest = OneTimeWorkRequest.Builder(NotificationWorker::class.java)
                .setInitialDelay(randomDelay, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueue(notificationWorkRequest)
        }
    }
}
