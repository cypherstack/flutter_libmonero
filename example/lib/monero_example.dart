import 'dart:async';
import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_libmonero/flutter_libmonero.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'util.dart';

FlutterSecureStorage? storage;
MoneroWallet? wallet;

Timer? t;

Watcher? watcher;

void setWatcher(Wallet wallet) {
  watcher = Watcher(
    wallet: wallet,
    pollingInterval: Duration(seconds: 1),
    onNewTransaction: () {
      loggerPrint("Watcher.onNewTransaction() triggered");
    },
    onSyncingUpdate: (syncingHeight, nodeHeight) {
      print("============================================================");
      loggerPrint("syncingHeight: $syncingHeight");
      loggerPrint("nodeHeight: $nodeHeight");
      loggerPrint("remaining: ${nodeHeight - syncingHeight}");
      loggerPrint(
          "sync percent: ${(syncingHeight / nodeHeight * 100).toStringAsFixed(2)}");
      print("============================================================");
    },
    onError: (e, s) {
      loggerPrint("error: $e");
      loggerPrint("stack trace: $s");
    },
  );

  watcher?.start();
}

Future<void> createWallet() async {
  try {
    final name = "namee${Random().nextInt(10000000)}";

    final path = await pathForWallet(name: name, type: "monero");

    // To restore from a seed
    wallet = await MoneroWallet.create(
      path: path,
      password: "password",
      seedType: MoneroSeedType.sixteen,
    );

    final success = await wallet?.initConnection(
      daemonAddress: "monero.stackwallet.com:18081",
      trusted: true,
      useSSL: true,
    );

    loggerPrint("initConnection success=$success");

    final address = wallet?.getAddress();
    loggerPrint(address);

    // ???
    // wallet?.setRefreshFromBlockHeight(height: height);
    // wallet?.startRescan();
    // wallet?.startRefreshAsync();

    loggerPrint("${wallet?.getSeed()}");
    await wallet?.refreshTransactions();
  } catch (e, s) {
    loggerPrint(e);
    loggerPrint(s);
  }
}

Future<void> runRestore() async {
  try {
    final name = "namee${Random().nextInt(10000000)}";

    final path = await pathForWallet(name: name, type: "monero");

    // final mnemonic = ("water " * 25).trim();
    final mnemonic =
        "ambush casket goodbye bimonthly arrow iris devoid mechanic hefty "
        "estate cowl listen ongoing joining fierce oust enlist exult "
        "hesitate daft sovereign otherwise inquest italics mechanic";
    final height = 2800000; // ~ jan 2023

    // To restore from a seed
    wallet = await MoneroWallet.restoreWalletFromSeed(
      path: path,
      password: "lol",
      seed: mnemonic,
      restoreHeight: height,
    );

    final success = await wallet?.initConnection(
      daemonAddress: "monero.stackwallet.com:18081",
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

    setWatcher(wallet!);
  } catch (e, s) {
    loggerPrint(e);
    loggerPrint(s);
  }
}

class MoneroExample extends StatefulWidget {
  @override
  _MoneroExampleState createState() => _MoneroExampleState();
}

class _MoneroExampleState extends State<MoneroExample> {
  Timer? timer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monero'),
      ),
      body: Center(
        child: ListView(
          children: [
            TextButton(
              onPressed: runRestore,
              child: Text(
                "run restore",
              ),
            ),
            // TextButton(
            //     onPressed: () async {
            //       String addr = wallet!.getTransaction(
            //           wownero.getCurrentAccount(walletBase!).id!, 0);
            //       loggerPrint("addr: $addr");
            //       for (var bal in walletBase!.balance!.entries) {
            //         loggerPrint(
            //             "key: ${bal.key}, amount ${moneroAmountToString(amount: bal.value.available)}");
            //       }
            //     },
            //     child: Text("amount")),
            // TextButton(
            //   onPressed: () async {
            //     Output output = Output(walletBase!); //
            //     output.address =
            //         "45ssGbDbLTnjdhpAm89PDpHpj6r5xWXBwL6Bh8hpy3PUcEnLgroo9vFJ9UE3HsAT5TTSk3Cqe2boJQHePAXisQSu9i6tz5A";
            //     output.setCryptoAmount("0.00001011");
            //     List<Output> outputs = [output];
            //     Object tmp =
            //         wownero.createWowneroTransactionCreationCredentials(
            //             outputs: outputs,
            //             priority: wownero.getDefaultTransactionPriority());
            //     loggerPrint(tmp);
            //     final awaitPendingTransaction =
            //         walletBase!.createTransaction(tmp, inputs: null);
            //     loggerPrint(output);
            //     final pendingWowneroTransaction =
            //        awaitPendingTransaction ;
            //     loggerPrint(pendingWowneroTransaction);
            //     loggerPrint(pendingWowneroTransaction.id);
            //     loggerPrint(pendingWowneroTransaction.amountFormatted);
            //     loggerPrint(pendingWowneroTransaction.feeFormatted);
            //     loggerPrint(pendingWowneroTransaction
            //         .pendingTransactionDescription.amount);
            //     loggerPrint(pendingWowneroTransaction
            //         .pendingTransactionDescription.hash);
            //     loggerPrint(pendingWowneroTransaction
            //         .pendingTransactionDescription.fee);
            //     loggerPrint(pendingWowneroTransaction
            //         .pendingTransactionDescription.pointerAddress);
            //     try {
            //       await pendingWowneroTransaction.commit();
            //       loggerPrint(
            //           "transaction ${pendingWowneroTransaction.id} has been sent");
            //     } catch (e, s) {
            //       loggerPrint("error");
            //       loggerPrint(e);
            //       loggerPrint(s);
            //     }
            //   },
            //   child: Text("send Transaction"),
            // ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Result: ${wallet?.getNodeHeight()}'),
                  ),
                  TextButton(
                    onPressed: () {
                      final tcCount = wallet?.transactionCount();

                      print("=============================================");
                      print("countOfTransactions: $tcCount");
                      print(
                          "wallet?.getCurrentHeight(): ${wallet?.getCurrentHeight()}");
                      print(
                          "wallet?.getNodeHeight(): ${wallet?.getNodeHeight()}");

                      print("=============================================");
                    },
                    child: Text("Click"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
