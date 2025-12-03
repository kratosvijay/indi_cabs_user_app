// import 'package:flutter/material.dart';


// class LoadingDialog extends StatelessWidget {

//   LoadingDialog({super.key,});

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       backgroundColor: Colors.transparent,
//       child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green),),
//     );
//   }
// }




import 'package:flutter/material.dart';


class LoadingDialog extends StatelessWidget {
  final String? message;

  const LoadingDialog({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: key,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CircularProgressIndicator
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 14),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),

          const SizedBox(height: 10),

          // Message
          Text(
            message ?? "Please wait...",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
