import 'dart:async';
import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_libmonero/flutter_libmonero.dart';

import 'util.dart';

MoneroWallet? wallet;

void addListener(MoneroWallet wallet) {
  wallet.addListener(WalletListener(
    onSyncingUpdate: onSyncingUpdate,
    onError: (e, s) {
      Logging.log?.e("onSyncingUpdate failed", error: e, stackTrace: s);
    },
    // onNewBlock: (int height) {},
    // onBalancesChanged: (int newBalance, int newUnlockedBalance) {},
  ));

  wallet.startListeners();
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

    final success = await wallet?.connect(
      daemonAddress: "monero.stackwallet.com:18081",
      trusted: true,
      useSSL: true,
    );

    Logging.log?.i("connect success=$success");
    addListener(wallet!);
    wallet?.startAutoSaving();
  } catch (e, s) {
    Logging.log?.e("create failed", error: e, stackTrace: s);
  }
}

Future<void> openWallet() async {
  try {
    final name = "namee5046961";

    final path = await pathForWallet(name: name, type: "monero");

    // To restore from a seed
    wallet = MoneroWallet.loadWallet(
      path: path,
      password: "lol",
    );

    final success = await wallet?.connect(
      daemonAddress: "monero.stackwallet.com:18081",
      trusted: true,
      useSSL: true,
    );

    Logging.log?.i("connect success=$success");
    addListener(wallet!);
    wallet?.startAutoSaving();
  } catch (e, s) {
    Logging.log?.e("open failed", error: e, stackTrace: s);
  }
}

class MoneroExample extends StatefulWidget {
  @override
  _MoneroExampleState createState() => _MoneroExampleState();
}

class _MoneroExampleState extends State<MoneroExample> {
  Timer? timer;

  final mnemonicController = TextEditingController();
  final restoreHeightController = TextEditingController();

  Future<void> runRestore() async {
    try {
      if (mnemonicController.text.isEmpty) {
        Logging.log?.e("Missing mnemonic!");
        return;
      }

      final name = "namee${Random().nextInt(10000000)}";

      final path = await pathForWallet(name: name, type: "monero");

      final mnemonic = mnemonicController.text;
      final height = int.tryParse(restoreHeightController.text);

      // To restore from a seed
      wallet = await MoneroWallet.restoreWalletFromSeed(
        path: path,
        password: "lol",
        seed: mnemonic,
        restoreHeight: height ?? 0,
      );

      final success = await wallet?.connect(
        daemonAddress: "monero.stackwallet.com:18081",
        trusted: true,
        useSSL: true,
      );

      addListener(wallet!);
      wallet?.startAutoSaving();
      Logging.log?.i("connect success=$success");

      unawaited(wallet?.rescanBlockchain());

      wallet?.startSyncing();
    } catch (e, s) {
      Logging.log?.e("restore failed", error: e, stackTrace: s);
    }
  }

  @override
  void dispose() {
    mnemonicController.dispose();
    restoreHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monero'),
      ),
      body: Center(
        child: ListView(
          children: [
            Column(
              children: [
                TextButton(
                  onPressed: runRestore,
                  child: Text(
                    "run restore",
                  ),
                ),
                TextField(
                  controller: mnemonicController,
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  controller: restoreHeightController,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: openWallet,
              child: Text(
                "run open",
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

            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                wallet?.startSyncing();
              },
              child: Text("Start Syncing"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                wallet?.stopSyncing();
                await wallet?.save();
              },
              child: Text("Stop Syncing"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                unawaited(wallet?.rescanBlockchain());
              },
              child: Text("Start Rescan"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                printWalletInfo(wallet!);
              },
              child: Text("Print Info"),
            ),
          ],
        ),
      ),
    );
  }
}
