import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grane/post_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'api/api.dart';
import 'common.dart';
import 'image_bloc.dart';
import 'multiselect_formfield.dart';
import 'etiquette_exp.dart';
import 'image_bloc_provider.dart';
import 'strings.dart';
import 'dropdown_string_button.dart';
import 'circle_thumbnail.dart';
import 'upload_and_scan_image.dart';

class AddEvent extends StatefulWidget {
  const AddEvent({Key key, this.restaurantData}) : super(key: key);

  @override
  AddEventState createState() => AddEventState(restaurantData);
  final RestaurantData restaurantData;
}

class AddEventState extends State<AddEvent> {
  AddEventState(this.restaurantData);

  final RestaurantData restaurantData;
  static final double MAIN_IMG_SIZE = 240.0;
  static final double SUB_IMG_SIZE = 84.0;
  bool isPosting = false;
  EventBLoCProvider provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => provider.postBloc.restaurant.add(this.restaurantData));
  }

  @override
  Widget build(BuildContext context) {
    provider = EventBLoCProvider.of(context);

    void _showSubmitResultDialog(bool result) {
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (_) {
            return AlertDialog(
                title: Text(result ? "投稿完了" : "投稿失敗"),
                content: Text(result ? "投稿しました" : "投稿失敗しました\n時間をあけて再度送信してください"),
                actions: <Widget>[
                  FlatButton(
                      child: Text('閉じる'),
                      onPressed: () {
                        if (result) {
                          Navigator.of(context, rootNavigator: true)
                              .pop('dialog');
                          Navigator.popUntil(
                              context, ModalRoute.withName("/top"));
                        } else {
                          Navigator.of(context, rootNavigator: true)
                              .pop('dialog');
                        }
                      })
                ]);
          });
    }

    void _submit() async {
      if (isPosting) {
        return;
      }
      isPosting = true;
      ProgressDialog pr = ProgressDialog(context);
      pr.style(
        message: '投稿中…',
        messageTextStyle: TextStyle(
            color: Colors.black, fontSize: 16.0, fontWeight: FontWeight.normal),
      );
      pr.show();
      provider.postBloc.submit().then((result) {
        isPosting = false;
        pr.dismiss();
        _showSubmitResultDialog(result == "success");
      }).catchError((error) {
        isPosting = false;
        pr.dismiss();
        _showSubmitResultDialog(false);
      });
    }

    return Material(
        child: Scaffold(
            appBar: AppBar(
              title: APP_BAR_LOGO,
              actions: <Widget>[
                FlatButton(
                    child: Text('記録', style: TextStyle(color: Colors.white)),
                    onPressed: isPosting ? null : () => _submit())
              ],
            ),
            body: SingleChildScrollView(
                child: Stack(
              children: <Widget>[
                _mainThumbnail(provider),
                _subThumbnail(provider),
                _mainForm(provider.postBloc)
              ],
            ))));
  }

  Future getImage(BuildContext context, bool isMainThumbnail) async {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (_) {
          return _importPhotoDialog(context, isMainThumbnail);
        });
  }

  Widget _mainThumbnail(EventBLoCProvider provider) {
    return StreamBuilder<File>(
        stream: provider.imgBloc.onMainThumbFile,
        builder: (context, snapshot) {
          return Column(
            children: <Widget>[
              GestureDetector(
                  onTap: () {
                    getImage(context, true);
                  },
                  child: Container(
                    height: MAIN_IMG_SIZE,
                    child: Stack(
                      children: <Widget>[
                        Container(
                            child: Align(
                                alignment: Alignment.center,
                                child: SizedBox.expand(
                                    child: snapshot.hasData
                                        ? Image.file(
                                            snapshot.data,
                                            fit: BoxFit.cover,
                                          )
                                        : SizedBox.shrink()))),
                        Container(
                          height: MAIN_IMG_SIZE,
                          color: filter,
                        ),
                        Container(
                          height: MAIN_IMG_SIZE,
                          child: Align(
                              alignment: Alignment.center,
                              child: Icon(Icons.image, color: Colors.white)),
                        )
                      ],
                    ),
                  ))
            ],
          );
        });
  }

  Widget _subThumbnail(EventBLoCProvider provider) {
    return StreamBuilder<File>(
        stream: provider.imgBloc.onSubThumbFile,
        builder: (context, snapshot) {
          return Positioned(
              top: 198,
              left: 16.0,
              child: Stack(
                children: <Widget>[
                  Positioned(
                      top: 1,
                      left: 1,
                      child: CircleThumbnail(
                          size: SUB_IMG_SIZE - 2, file: snapshot.data)),
                  Container(
                      width: SUB_IMG_SIZE,
                      height: SUB_IMG_SIZE,
                      child: Container(
                          margin: EdgeInsets.all(1.0),
                          child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular((SUB_IMG_SIZE - 2) / 2),
                              child: Container(color: filter)))),
                  GestureDetector(
                      onTap: () {
                        showDialog(
                            barrierDismissible: true,
                            context: context,
                            builder: (_) {
                              return GestureDetector(
                                child: EtiquetteExp(),
                                onTap: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop('dialog');
                                  getImage(context, false);
                                },
                              );
                            });
                      },
                      onLongPress: () {
                        if (snapshot.hasData) {
                          showDialog(
                              barrierDismissible: true,
                              context: context,
                              builder: (_) {
                                return AlertDialog(
                                    title: Text("画像のリセット"),
                                    content: Text("選択した画像をリセットしますか？"),
                                    actions: <Widget>[
                                      FlatButton(
                                          child: Text('いいえ'),
                                          onPressed: () => Navigator.of(context,
                                                  rootNavigator: true)
                                              .pop('dialog')),
                                      FlatButton(
                                          child: Text('はい'),
                                          onPressed: () {
                                            provider.imgBloc.subThumbFile
                                                .add(null);
                                            provider.postBloc.subThumb
                                                .add(null);
                                            Navigator.of(context,
                                                    rootNavigator: true)
                                                .pop('dialog');
                                          })
                                    ]);
                              });
                        }
                      },
                      child: Container(
                          width: SUB_IMG_SIZE,
                          height: SUB_IMG_SIZE,
                          decoration: BoxDecoration(
                            border:
                                Border.all(width: 3, color: Color(0xFFFFFFFF)),
                            borderRadius:
                                BorderRadius.circular(SUB_IMG_SIZE / 2),
                          ),
                          child: Align(
                              alignment: Alignment.center,
                              child: Icon(Icons.image, color: Colors.white))))
                ],
              ));
        });
  }

  Widget _importPhotoDialog(context, isMain) {
    ImageBloc bloc = provider.imgBloc;
    PostBloc postBloc = provider.postBloc;
    return AlertDialog(
        title: Text("写真の取り込み"),
        content: Container(
            height: 280,
            child: Column(
              children: <Widget>[
                InkWell(
                  child: Column(
                    children: <Widget>[
                      Container(
                          padding: EdgeInsets.all(12.0),
                          child: Image.asset("images/photo_camera.png"),
                          width: 100),
                      Container(
                          child: Text(
                            "カメラで撮影",
                            style: TEXT_STYLE,
                          ),
                          margin: EdgeInsets.only(top: 8))
                    ],
                  ),
                  onTap: () async {
                    Navigator.of(context, rootNavigator: true).pop('dialog');
                    var image =
                        await ImagePicker.pickImage(source: ImageSource.camera);
                    if (isMain) {
                      bloc.mainThumbFile.add(image);
                    } else {
                      bloc.subThumbFile.add(image);
                    }
                    uploadAndScanImage(context, isMain, image, postBloc);
                  },
                ),
                Container(height: 20),
                InkWell(
                  child: Column(
                    children: <Widget>[
                      Container(
                          padding: EdgeInsets.all(12.0),
                          child: Image.asset("images/photo_library.png"),
                          width: 100),
                      Container(
                          child: Text("ギャラリーから選択", style: TEXT_STYLE),
                          margin: EdgeInsets.only(top: 8))
                    ],
                  ),
                  onTap: () async {
                    Navigator.of(context, rootNavigator: true).pop('dialog');
                    var image = await ImagePicker.pickImage(
                        source: ImageSource.gallery);
                    if (isMain) {
                      bloc.mainThumbFile.add(image);
                    } else {
                      bloc.subThumbFile.add(image);
                    }
                    uploadAndScanImage(context, isMain, image, postBloc);
                  },
                ),
              ],
            )),
        actions: <Widget>[
          FlatButton(
              child: Text('閉じる'),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop('dialog');
              })
        ]);
  }

  Widget _mainForm(PostBloc bloc) {
    final dataSource = [];
    for (var i = 0; i < Strings.WINE_VARIETIES.length; i++) {
      String val = Strings.WINE_VARIETIES[i];
      dataSource.add({"display": val, "value": val});
    }

    return Form(
        child: Container(
      margin:
          EdgeInsets.only(top: 302.0, left: 16.0, right: 16.0, bottom: 24.0),
      child: Column(
        children: <Widget>[
          FormItem(
              childWidget: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      restaurantData != null ? restaurantData.name : "自宅など持ち帰り",
                      style: FORM_TEXT_STYLE))),
          FormItem(
              childWidget: Align(
                  alignment: Alignment.centerLeft,
                  child: StreamBuilder<String>(
                      stream: bloc.onWineName,
                      builder: (context, snapshot) {
                        return TextFormField(
                            onChanged: (text) {
                              bloc.wineNameFromText.add(text);
                            },
                            controller: bloc.wineNameTextFieldController(),
                            validator: (value) {
                              if (value.isEmpty) {
                                return "名称を入力してください";
                              }
                              return null;
                            },
                            decoration: new InputDecoration(
                              enabledBorder: TEXT_INPUT_UNDERLINE,
                              labelText: 'ワインの名前や商品名',
                            ),
                            style: FORM_TEXT_STYLE);
                      }))),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                    width: 160,
                    height: 64,
                    child: StreamBuilder<String>(
                        stream: bloc.onPriceUnit,
                        builder: (context, snapshot) {
                          return FormItem(
                              childWidget: DropdownStringButton(
                                  items: Strings.PRICE_UNITS,
                                  value:
                                      snapshot.hasData ? snapshot.data : null,
                                  hint: Container(
                                      margin: EdgeInsets.only(bottom: 0),
                                      child: Text(
                                        'グラス/ボトル',
                                      )),
                                  onChanged: (value) {
                                    debugPrint(value);
                                    bloc.priceUnit.add(value);
                                  }));
                        }))),
            Container(
                margin: EdgeInsets.only(left: 12, right: 12, bottom: 6),
                child: Text('あたり約', style: FORM_TEXT_STYLE)),
            Container(
                width: 64,
                margin: EdgeInsets.only(bottom: 6),
                child: FormItem(
                    childWidget: Align(
                        alignment: Alignment.centerLeft,
                        child: TextFormField(
                          onChanged: (text) {
                            logger.i("price:${text}");
                            bloc.price.add(text);
                          },
                          controller: bloc.priceTextFieldController(),
                          validator: (value) {
                            if (value.isEmpty) {
                              return "金額を入力してください";
                            }
                            return null;
                          },
                          maxLength: 7,
                          focusNode: bloc.getPriceFocusNode(),
                          keyboardType: TextInputType.number,
                          decoration: new InputDecoration(
                              enabledBorder: TEXT_INPUT_UNDERLINE,
                              labelText: '金額',
                              counterText: ''),
                          style: FORM_TEXT_STYLE,
                        )))),
            Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                    child: Text('円', style: FORM_TEXT_STYLE),
                    margin: EdgeInsets.only(left: 8)))
          ]),
          FormItem(
              childWidget: Align(
            alignment: Alignment.centerLeft,
            child: TextFormField(
                onChanged: (text) {
                  bloc.comment.add(text);
                },
                controller: bloc.getCommentTextFieldController(),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                validator: (value) {
                  if (value.isEmpty) {
                    return "コメントを入力してください";
                  }
                  return null;
                },
                decoration: new InputDecoration(
                  border: const UnderlineInputBorder(),
                  labelText: 'コメント',
                ),
                style: FORM_TEXT_STYLE),
          )),
          Container(
              margin: EdgeInsets.only(top: 32),
              child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                      title: Text(
                        "詳しく書く",
                        style: TEXT_STYLE,
                      ),
                      children: <Widget>[
                        Column(children: <Widget>[
                          Container(
                              child: StreamBuilder<String>(
                                  stream: bloc.onCountry,
                                  builder: (context, snapshot) {
                                    return FormItem(
                                        childWidget: DropdownStringButton(
                                            items: Strings.COUNTRIES,
                                            value: snapshot.hasData
                                                ? snapshot.data
                                                : null,
                                            hint: Container(
                                                margin:
                                                    EdgeInsets.only(bottom: 14),
                                                child: Text(
                                                  'ワインの原産国',
                                                )),
                                            onChanged: (value) {
                                              FocusScope.of(context)
                                                  .requestFocus(FocusNode());
                                              debugPrint(value);
                                              bloc.country.add(value);
                                            }));
                                  })),
                          Container(
                              margin: EdgeInsets.only(top: 16),
                              child: StreamBuilder<String>(
                                  stream: bloc.onType,
                                  builder: (context, snapshot) {
                                    return FormItem(
                                        childWidget: DropdownStringButton(
                                            items: Strings.WINE_CATEGORIES,
                                            value: snapshot.hasData
                                                ? snapshot.data
                                                : null,
                                            hint: Container(
                                                margin:
                                                    EdgeInsets.only(bottom: 14),
                                                child: Text(
                                                  'ワインの種類',
                                                )),
                                            onChanged: (value) {
                                              FocusScope.of(context)
                                                  .requestFocus(FocusNode());
                                              debugPrint(value);
                                              bloc.type.add(value);
                                            }));
                                  })),
                          Container(
                              margin: EdgeInsets.only(top: 10),
                              child: StreamBuilder<String>(
                                  stream: bloc.onWineVariety,
                                  builder: (context, snapshot) {
                                    return FormItem(
                                        childWidget: DropdownStringButton(
                                            value: snapshot.hasData
                                                ? snapshot.data
                                                : null,
                                            items: Strings.WINE_VARIETIES,
                                            hint: Container(
                                                margin:
                                                    EdgeInsets.only(bottom: 14),
                                                child: Text(
                                                  '一番比率が高い葡萄の品種',
                                                )),
                                            onChanged: (value) {
                                              FocusScope.of(context)
                                                  .requestFocus(FocusNode());
                                              debugPrint(value);
                                              bloc.wineVariety.add(value);
                                            }));
                                  })),
                          FormItem(
                              childWidget: Form(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: StreamBuilder<List<String>>(
                                      stream: bloc.onWineSubVariety,
                                      builder: (context, snapshot) {
                                        return MultiSelectFormField(
                                          autovalidate: false,
                                          titleText: 'その他の品種',
                                          validator: (value) {
                                            return null;
                                          },
                                          dataSource: dataSource,
                                          textField: 'display',
                                          valueField: 'value',
                                          okButtonLabel: '選択',
                                          cancelButtonLabel: 'キャンセル',
                                          // required: true,
                                          hintText: 'その他の品種',
                                          value: snapshot.hasData
                                              ? snapshot.data
                                              : null,
                                          onSaved: (value) {
                                            FocusScope.of(context)
                                                .requestFocus(FocusNode());
                                            FocusScope.of(context).requestFocus(
                                                bloc.getTagFocusNode());
                                            logger.d("value:${value}");
                                            List<String> tmp = List<String>();
                                            value.forEach((item) =>
                                                tmp.add(item.toString()));
                                            bloc.wineSubVariety.add(tmp);
                                          },
                                        );
                                      }),
                                ),
                              ],
                            ),
                          )),
                          FormItem(
                              childWidget: Align(
                            alignment: Alignment.centerLeft,
                            child: TextFormField(
                                onChanged: (text) {
                                  bloc.placeTag.add(text);
                                },
                                controller: bloc.getTagTextFieldController(),
                                maxLines: 1,
                                focusNode: bloc.getTagFocusNode(),
                                decoration: new InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: 'タグ',
                                    hintText: '東京,新宿'),
                                style: FORM_TEXT_STYLE),
                          )),
                        ])
                      ])))
        ],
      ),
    ));
  }
}
