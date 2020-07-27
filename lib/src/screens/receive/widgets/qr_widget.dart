import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/receive/widgets/qr_image.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/core/amount_validator.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:cake_wallet/palette.dart';

class QRWidget extends StatelessWidget {
  QRWidget({
    @required this.addressListViewModel,
    this.isAmountFieldShow = false
  }) : amountController = TextEditingController(),
    _formKey = GlobalKey<FormState>() {
    amountController.addListener(() => addressListViewModel.amount =
    _formKey.currentState.validate() ? amountController.text : '');
  }

  final WalletAddressListViewModel addressListViewModel;
  final bool isAmountFieldShow;
  final TextEditingController amountController;
  final GlobalKey<FormState> _formKey;

  @override
  Widget build(BuildContext context) {
    final copyImage = Image.asset('assets/images/copy_address.png',
          color: PaletteDark.lightBlueGrey);
    final addressTopOffset = isAmountFieldShow ? 60.0 : 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Row(children: <Widget>[
          Spacer(flex: 2),
          Observer(
            builder: (_) => Flexible(
              flex: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: QrImage(
                    data: addressListViewModel.uri.toString(),
                    backgroundColor: Colors.transparent,
                    foregroundColor: PaletteDark.lightBlueGrey,
          ))))),
          Spacer(flex: 2)
        ]),
        Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text(
            'Scan the QR code to get the address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PaletteDark.cyanBlue
            ),
          ),
        ),
        isAmountFieldShow
        ? Padding(
          padding: EdgeInsets.only(top: 60),
          child: Row(
            children: <Widget>[
              Expanded(
                  child: Form(
                      key: _formKey,
                      child: BaseTextFormField(
                          controller: amountController,
                          keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            BlacklistingTextInputFormatter(
                                RegExp('[\\-|\\ |\\,]'))
                          ],
                          textAlign: TextAlign.center,
                          hintText: S.of(context).receive_amount,
                          borderColor: PaletteDark.darkGrey,
                          validator: AmountValidator(),
                          autovalidate: true,
                          placeholderTextStyle: TextStyle(
                              color: PaletteDark.cyanBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w500))))
            ],
          ),
        )
        : Offstage(),
        Padding(
          padding: EdgeInsets.only(top: addressTopOffset),
          child: Builder(
              builder: (context) => Observer(
                  builder: (context) => GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: addressListViewModel.address.address));
                      Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text(
                          S.of(context).copied_to_clipboard,
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(milliseconds: 500),
                      ));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            addressListViewModel.address.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: copyImage,
                        )
                      ],
                    ),
                  ))),
        )
      ],
    );
  }
}