import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

// ওয়েব এবং মোবাইলের জন্য কন্ডিশনাল ইম্পোর্ট
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

class MediaViewPage extends StatefulWidget {
  final String url;
  final String type;

  const MediaViewPage({super.key, required this.url, required this.type});

  @override
  State<MediaViewPage> createState() => _MediaViewPageState();
}

class _MediaViewPageState extends State<MediaViewPage> {
  bool isDownloading = false;

  Future<void> downloadMedia() async {
    setState(() {
      isDownloading = true;
    });

    try {
      String extension = widget.type == 'image' ? 'jpg' : 'mp4';
      String fileName =
          "chat_media_${DateTime.now().millisecondsSinceEpoch}.$extension";

      if (kIsWeb) {
        // 🌐 ক্রোমের (Web) জন্য ডিরেক্ট ব্যাকগ্রাউন্ড ডাউনলোড
        final response = await Dio().get(
          widget.url,
          options: Options(responseType: ResponseType.bytes),
        );

        final blob = html.Blob([response.data]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();

        html.Url.revokeObjectUrl(url);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download completed successfully!")),
        );
      } else {
        // 📱 অ্যান্ড্রয়েড/আইওএস মোবাইলের জন্য ডিরেক্ট গ্যালারি সেভ
        final tempDir = await getTemporaryDirectory();
        final String filePath = "${tempDir.path}/$fileName";

        await Dio().download(widget.url, filePath);

        if (widget.type == 'image') {
          await GallerySaver.saveImage(filePath, albumName: "ChatApp");
        } else if (widget.type == 'video') {
          await GallerySaver.saveVideo(filePath, albumName: "ChatApp");
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Media saved directly to your Gallery!"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Download failed: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF090A0F,
      ), // আল্ট্রা-ডার্ক মডার্ন ব্ল্যাক ব্যাকগ্রাউন্ড
      extendBodyBehindAppBar:
          true, // কনটেন্ট যেন অ্যাপবারের পেছনেও সুন্দরভাবে ছড়ায়
      appBar: AppBar(
        backgroundColor: Colors.transparent, // ট্রান্সপারেন্ট অ্যাপবার
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(
              0.4,
            ), // আইকনের পেছনে হালকা গ্লাস বাবল
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          widget.type == 'image' ? "Image Preview" : "Video Preview",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          // ডিরেক্ট ডাউনলোড ইন্ডিকেটর বা বাটন অ্যাপবারের ডানপাশেও ক্লাসি লুকে থাকবে
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.4),
              child: isDownloading
                  ? const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                        strokeWidth: 2.5,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: downloadMedia,
                      tooltip: "Save to Device",
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ====== 🖼️ মেইন মিডিয়া এরিয়া (সেন্টার ভিউয়ার) ======
          Center(
            child: widget.type == "image"
                ? InteractiveViewer(
                    maxScale: 4.0, // সর্বোচ্চ জুম লেভেল ৪ গুণ পর্যন্ত
                    minScale: 0.8,
                    child: Hero(
                      tag: widget
                          .url, // স্মুথ ট্রানজিশনের জন্য হিরো অ্যানিমেশন ট্যাগ সমর্থন
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const CircularProgressIndicator(
                            color: Colors.blueAccent,
                          );
                        },
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded, // বোল্ড ও ক্লিনার প্লে বাটন
                        size: 64,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
          ),

          // ====== 📥 বটম মডার্ন ফ্লোটিং ডাউনলোডার প্যানেল ======
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF1E293B,
                  ).withOpacity(0.75), // ব্লার এফেক্ট ফিল স্লেট
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: isDownloading ? null : downloadMedia,
                  borderRadius: BorderRadius.circular(30),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.blueAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              widget.type == 'image'
                                  ? Icons.image_rounded
                                  : Icons.movie_rounded,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                      const SizedBox(width: 12),
                      Text(
                        isDownloading
                            ? "Saving to Gallery..."
                            : "Save to Device",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (!isDownloading) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.download_rounded,
                          color: Colors.white.withOpacity(0.6),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
