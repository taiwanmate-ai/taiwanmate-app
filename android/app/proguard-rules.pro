# ML Kit — giu class that su ton tai (sau khi da them dependency chinese),
# va bo qua canh bao cho cac class script khac (japanese/korean/devanagari)
# ma app nay khong dung toi, tranh R8 bao loi ve chung.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**