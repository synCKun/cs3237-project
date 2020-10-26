import datetime
import csv

with open('data_raw.csv', 'r', newline='') as csvfile:
    with open('data_processed.csv', 'w+', newline='') as outputfile:
        reader = csv.reader(csvfile)
        writer = csv.writer(outputfile)
        prevTime = None
        count = 0
        optical_sum = 0.0
        humidity_sum = 0.0
        humidity_temp_sum = 0.0
        barometer_sum = 0.0
        barometer_temp_sum = 0.0
        initTime = None
        for row in reader:
            time, optical, humidity, humidity_temp, barometer, barometer_temp = row
            time = time[:time.find('.')]
            time = datetime.datetime.strptime(time, "%Y-%m-%d %H:%M:%S")
            if initTime == None:
                initTime = time
            if (time - initTime).total_seconds() < 10:
                continue
            if time != prevTime:
                if prevTime != None:
                    optical_avg = optical_sum / count;
                    humidity_avg = humidity_sum / count;
                    humidity_temp_avg = humidity_temp_sum / count;
                    barometer_avg = barometer_sum / count;
                    barometer_temp_avg = barometer_temp_sum / count;
                    writer.writerow([prevTime, optical_avg, humidity_avg, humidity_temp_avg, barometer_avg, barometer_temp_avg])
                    count = 0
                    optical_sum = 0.0;
                    humidity_sum = 0.0;
                    humidity_temp_sum = 0.0;
                    barometer_sum = 0.0;
                    barometer_temp_sum = 0.0;
            optical_sum += float(optical)
            humidity_sum += float(humidity)
            humidity_temp_sum += float(humidity_temp)
            barometer_sum += float(barometer)
            barometer_temp_sum += float(barometer_temp)
            count += 1
            prevTime = time
        optical_avg = optical_sum / count;
        humidity_avg = humidity_sum / count;
        humidity_temp_avg = humidity_temp_sum / count;
        barometer_avg = barometer_sum / count;
        barometer_temp_avg = barometer_temp_sum / count;
        writer.writerow([prevTime, optical_avg, humidity_avg, humidity_temp_avg, barometer_avg, barometer_temp_avg])


