import 'dart:async';
import 'dart:core' as core;
import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_libmonero/flutter_libmonero.dart';
import 'package:flutter_libmonero_example/util.dart';

WowneroWallet? wallet;

void addListener(WowneroWallet wallet) {
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

    final success = await wallet?.connect(
      daemonAddress: "eu-west-2.wow.xmr.pm:34568",
      trusted: true,
      useSSL: true,
    );

    Logging.log?.i("connect success=$success");

    // wallet?.rescan
    unawaited(wallet?.rescanBlockchain());
    wallet?.startSyncing();
  } catch (e, s) {
    Logging.log?.e("restore failed", error: e, stackTrace: s);
  }
}

Future<void> tx() async {
  try {
    final pendingWowneroTransaction = await wallet!.createTx(
      address:
          "45ssGbDbLTnjdhpAm89PDpHpj6r5xWXBwL6Bh8hpy3PUcEnLgroo9vFJ9UE3HsAT5TTSk3Cqe2boJQHePAXisQSu9i6tz5A",
      paymentId: "",
      priority: TransactionPriority.low,
      amount: "0.00001011",
      preferredInputs: [],
    );

    Logging.log?.i(pendingWowneroTransaction);
    Logging.log?.i(pendingWowneroTransaction.txid);
    Logging.log?.i(pendingWowneroTransaction.amount);
    Logging.log?.i(pendingWowneroTransaction.fee);

    Logging.log?.i(pendingWowneroTransaction.pointerAddress);

    await wallet!.commitTx(
      pendingWowneroTransaction,
    );

    Logging.log?.i(
      "transaction ${pendingWowneroTransaction.txid} has been sent",
    );
  } catch (e, s) {
    Logging.log?.e("tx failed", error: e, stackTrace: s);
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
                    Logging.log?.i("address: $address");

                    final unlocked = wallet?.getUnlockedBalance();
                    final full = wallet?.getBalance();

                    Logging.log?.i("Full balance: $full");
                    Logging.log?.i("Unlocked balance: $unlocked");
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
