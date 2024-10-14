import 'dart:core' as core;
import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_libmonero/flutter_libmonero.dart';
import 'package:flutter_libmonero_example/util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

FlutterSecureStorage? storage;
WowneroWallet? wallet;

Future<void> runRestore() async {
  try {
    final name = "namee${Random().nextInt(10000000)}";

    final path = await pathForWallet(name: name, type: "wownero");

    final height = 10000;

    wallet = await WowneroWallet.restoreWalletFromSeed(
      path: path,
      password: "lol",
      seed: ("water " * 25).trim(),
      restoreHeight: height,
    );

    final success = await wallet?.initConnection(
      daemonAddress: "eu-west-2.wow.xmr.pm:34568",
      trusted: true,
      useSSL: true,
    );

    loggerPrint("initConnection success=$success");

    final address = wallet?.getAddress();
    loggerPrint(address);

    // wallet?.rescan
    wallet?.startRescan(null, height);
    wallet?.startRefreshAsync();

    loggerPrint("${wallet?.getSeed()}");
    await wallet?.refreshTransactions();
  } catch (e, s) {
    loggerPrint(e);
    loggerPrint(s);
  }
}

Future<void> tx() async {
  try {
    final pendingWowneroTransaction = await wallet!.createTransaction(
      address:
          "45ssGbDbLTnjdhpAm89PDpHpj6r5xWXBwL6Bh8hpy3PUcEnLgroo9vFJ9UE3HsAT5TTSk3Cqe2boJQHePAXisQSu9i6tz5A",
      paymentId: "",
      priority: TransactionPriority.low,
      amount: "0.00001011",
      preferredInputs: [],
    );

    loggerPrint(pendingWowneroTransaction);
    loggerPrint(pendingWowneroTransaction.hash);
    loggerPrint(pendingWowneroTransaction.amount);
    loggerPrint(pendingWowneroTransaction.fee);

    loggerPrint(pendingWowneroTransaction.pointerAddress);

    wallet!.commitTransaction(
      pendingTransaction: pendingWowneroTransaction,
    );

    loggerPrint(
      "transaction ${pendingWowneroTransaction.hash} has been sent",
    );
  } catch (e, s) {
    loggerPrint("error");
    loggerPrint(e);
    loggerPrint(s);
  }
}

class WowneroExample extends StatefulWidget {
  @override
  _WowneroExampleState createState() => _WowneroExampleState();
}

class _WowneroExampleState extends State<WowneroExample> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Wownero'),
        ),
        body: Center(
          child: ListView(
            children: [
              TextButton(
                  onPressed: () async {
                    final address = wallet?.getAddress();
                    loggerPrint("address: $address");

                    final unlocked = wallet?.getUnlockedBalance();
                    final full = wallet?.getFullBalance();

                    loggerPrint("Full balance: $full");
                    loggerPrint("Unlocked balance: $unlocked");
                  },
                  child: Text("balance")),
              TextButton(
                onPressed: tx,
                child: Text("send Transaction"),
              ),
              // Text(
              //     "bob ${wowneroAmountToString(amount: walletBase.transactionHistory.transactions.entries.first.value.amount)}"),
              FutureBuilder(
                future: runRestore(),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  List<Widget> children;
                  if (snapshot.hasData) {
                    children = <Widget>[
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 60,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('Restored. Syncing...'),
                      )
                    ];
                  } else if (snapshot.hasError) {
                    children = <Widget>[
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('Error: ${snapshot.error}'),
                      )
                    ];
                  } else {
                    children = const <Widget>[
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text('Restoring...'),
                      )
                    ];
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
