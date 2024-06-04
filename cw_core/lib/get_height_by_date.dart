import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// TODO/FIXME: Hardcoded values; need to update Monero from 2020-11 on

final dateFormat = DateFormat('yyyy-MM');
final moneroDates = {
  "2014-5": 18844,
  "2014-6": 65406,
  "2014-7": 108882,
  "2014-8": 153594,
  "2014-9": 198072,
  "2014-10": 241088,
  "2014-11": 285305,
  "2014-12": 328069,
  "2015-1": 372369,
  "2015-2": 416505,
  "2015-3": 456631,
  "2015-4": 501084,
  "2015-5": 543973,
  "2015-6": 588326,
  "2015-7": 631187,
  "2015-8": 675484,
  "2015-9": 719725,
  "2015-10": 762463,
  "2015-11": 806528,
  "2015-12": 849041,
  "2016-1": 892866,
  "2016-2": 936736,
  "2016-3": 977691,
  "2016-4": 1015848,
  "2016-5": 1037417,
  "2016-6": 1059651,
  "2016-7": 1081269,
  "2016-8": 1103630,
  "2016-9": 1125983,
  "2016-10": 1147617,
  "2016-11": 1169779,
  "2016-12": 1191402,
  "2017-1": 1213861,
  "2017-2": 1236197,
  "2017-3": 1256358,
  "2017-4": 1278622,
  "2017-5": 1300239,
  "2017-6": 1322564,
  "2017-7": 1344225,
  "2017-8": 1366664,
  "2017-9": 1389113,
  "2017-10": 1410738,
  "2017-11": 1433039,
  "2017-12": 1454639,
  "2018-1": 1477201,
  "2018-2": 1499599,
  "2018-3": 1519796,
  "2018-4": 1542067,
  "2018-5": 1562861,
  "2018-6": 1585135,
  "2018-7": 1606715,
  "2018-8": 1629017,
  "2018-9": 1651347,
  "2018-10": 1673031,
  "2018-11": 1695128,
  "2018-12": 1716687,
  "2019-1": 1738923,
  "2019-2": 1761435,
  "2019-3": 1781681,
  "2019-4": 1803081,
  "2019-5": 1824671,
  "2019-6": 1847005,
  "2019-7": 1868590,
  "2019-8": 1890552,
  "2019-9": 1912212,
  "2019-10": 1932200,
  "2019-11": 1957040,
  "2019-12": 1978090,
  "2020-1": 2001290,
  "2020-2": 2022688,
  "2020-3": 2043987,
  "2020-4": 2066536,
  "2020-5": 2090797,
  "2020-6": 2111633,
  "2020-7": 2131433,
  "2020-8": 2153983,
  "2020-9": 2176466,
  "2020-10": 2198453,
  "2020-11": 2220000
};

final wowneroDates = {
  "2018-05": 8725,
  "2018-06": 17533,
  "2018-07": 25981,
  "2018-08": 34777,
  "2018-09": 43633,
  "2018-10": 52165,
  "2018-11": 60769,
  "2018-12": 66817,
  "2019-01": 72769,
  "2019-02": 78205,
  "2019-03": 84805,
  "2019-04": 93649,
  "2019-05": 102277,
  "2019-06": 111193,
  "2019-07": 119917,
  "2019-08": 128797,
  "2019-09": 137749,
  "2019-10": 146377,
  "2019-11": 155317,
  "2019-12": 163933,
  "2020-01": 172861,
  "2020-02": 181801,
  "2020-03": 190141,
  "2020-04": 199069,
  "2020-05": 207625,
  "2020-06": 216385,
  "2020-07": 224953,
  "2020-08": 233869,
  "2020-09": 242773,
  "2020-10": 251401,
  "2020-11": 260365,
  "2020-12": 269077,
  "2021-01": 278017,
  "2021-02": 286945,
  "2021-03": 295033,
  "2021-04": 303949,
  "2021-05": 312637,
  "2021-06": 321601,
  "2021-07": 330277,
  "2021-08": 340093,
  "2021-09": 349141,
  "2021-10": 357625,
  "2021-11": 366433,
  "2021-12": 374869,
  "2022-01": 383713,
  "2022-02": 392389,
  "2022-03": 400525,
  "2022-04": 409441,
  "2022-05": 417913,
  "2022-06": 426769,
  "2022-07": 435205,
  "2022-08": 444157,
  "2022-09": 453157,
  "2022-10": 461737,
  "2022-11": 470617
};

/* Data above generated by bash script
#!/bin/bash

declare -A firstBlockOfTheMonth

for HEIGHT in {1..473084}
do
  TIMESTAMP=$(curl -s -X POST http://suchnode.verywow:34568/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"getblock","params":{"height":'$HEIGHT'}}' | jq '.result.block_header.timestamp')
  YRMO=$(date +'%Y-%m' -d "@"$TIMESTAMP) # Like "2022-11"
  if [ "${firstBlockOfTheMonth[$YRMO]+abc}" ]; then # Check if key $YRMO has been set in array firstBlockOfTheMonth
    continue # We've already seen a block in this month
  else # This is the first block of the month
    echo '"'$YRMO'": '$HEIGHT
    firstBlockOfTheMonth[$YRMO]=$HEIGHT # Like firstBlockOfTheMonth["2021-05"]=312769
  fi
done
*/

int getMoneroHeigthByDate({required DateTime date}) {
  final raw = '${date.year}' + '-' + '${date.month}';
  final lastHeight = moneroDates.values.last;
  int? startHeight;
  int? endHeight;
  int height = 0;

  try {
    if ((moneroDates[raw] == null) || (moneroDates[raw] == lastHeight)) {
      startHeight = moneroDates.values.toList()[moneroDates.length - 2];
      endHeight = moneroDates.values.toList()[moneroDates.length - 1];
      final heightPerDay = (endHeight - startHeight) / 31;
      final endDateRaw =
          moneroDates.keys.toList()[moneroDates.length - 1].split('-');
      final endYear = int.parse(endDateRaw[0]);
      final endMonth = int.parse(endDateRaw[1]);
      final endDate = DateTime(endYear, endMonth);
      final differenceInDays = date.difference(endDate).inDays;
      final daysHeight = (differenceInDays * heightPerDay).round();
      height = endHeight + daysHeight;
    } else {
      startHeight = moneroDates[raw];
      final index = moneroDates.values.toList().indexOf(startHeight!);
      endHeight = moneroDates.values.toList()[index + 1];
      final heightPerDay = ((endHeight - startHeight) / 31).round();
      final daysHeight = (date.day - 1) * heightPerDay;
      height = startHeight + daysHeight - heightPerDay;
    }
  } catch (e) {
    if (kDebugMode) print(e.toString());
  }

  return height;
}

int getWowneroHeightByDate({required DateTime date}) {
  final raw = '${date.year}' + '-' + '${date.month}';
  final lastHeight = wowneroDates.values.last;
  int? startHeight;
  int? endHeight;
  int height = 0;

  try {
    if ((wowneroDates[raw] == null) || (wowneroDates[raw] == lastHeight)) {
      startHeight = wowneroDates.values.toList()[wowneroDates.length - 2];
      endHeight = wowneroDates.values.toList()[wowneroDates.length - 1];
      final heightPerDay = (endHeight - startHeight) / 31;
      final endDateRaw =
          wowneroDates.keys.toList()[wowneroDates.length - 1].split('-');
      final endYear = int.parse(endDateRaw[0]);
      final endMonth = int.parse(endDateRaw[1]);
      final endDate = DateTime(endYear, endMonth);
      final differenceInDays = date.difference(endDate).inDays;
      final daysHeight = (differenceInDays * heightPerDay).round();
      height = endHeight + daysHeight;
    } else {
      startHeight = wowneroDates[raw];
      final index = wowneroDates.values.toList().indexOf(startHeight!);
      endHeight = wowneroDates.values.toList()[index + 1];
      final heightPerDay = ((endHeight - startHeight) / 31).round();
      final daysHeight = (date.day - 1) * heightPerDay;
      height = startHeight + daysHeight - heightPerDay;
    }
  } catch (e) {
    if (kDebugMode) print(e.toString());
  }

  return height;
}
