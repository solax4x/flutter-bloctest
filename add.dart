import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:progress_dialog/progress_dialog.dart';

import 'api/api.dart';
import 'common.dart';
import 'multiselect_formfield.dart';
import 'etiquette_exp.dart';

class AddPost extends StatefulWidget {
  const AddPost({Key key, this.restaurantData}) : super(key: key);

  @override
  AddPostState createState() => AddPostState(restaurantData);
  final RestaurantData restaurantData;
}

class AddPostState extends State<AddPost> {
  AddPostState(this.restaurantData);

  final formKey = new GlobalKey<AddFormState>();
  final formMainThumbnailKey = new GlobalKey<MainThumbnailState>();
  final RestaurantData restaurantData;
  var isPosting = false;

  String token;

  static var _context;

  final double subImageSize = 84.0;
  File _image;
  String _s3filename;

  static void setParams(name, varieties){
    if(_context!=null){
      _context.formKey.currentState.setName(name);
      if(varieties.length!=0){

      }
    }
  }

  Future<bool> _checkSignIn() async {
    debugPrint('_checkSignIn');
    String t = await getToken();
    setState(() {
      token = t;
    });
    debugPrint('token:${t}');

    if (t == null) {
      Future.delayed(const Duration(seconds: 0)).then(
          (value) => Navigator.of(context).pushReplacementNamed("/login"));
      return false;
    } else {
      return true;
    }
  }

  void init() async {
    bool result = await _checkSignIn();
    if (!result) {
      Navigator.of(context).pushReplacementNamed("/login");
    }
  }

  void showErrorDialog(body) {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (_) {
          return AlertDialog(
              title: Text("項目エラー"),
              content: Text(body),
              actions: <Widget>[
                FlatButton(
                    child: Text('閉じる'),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop('dialog');
                    })
              ]);
        });
  }

  Future getImage() async {

    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (_) {
          return AlertDialog(
              title: Text("写真の取り込み"),
              content: Container(height:280,child:Column(children: <Widget>[
                InkWell(child: Column(children: <Widget>[Container(padding:EdgeInsets.all(12.0),child:Image.asset("images/photo_camera.png"),width: 100),Container(child:Text("カメラで撮影",style: TEXT_STYLE,),margin:EdgeInsets.only(top:8))],),onTap:() async {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                  var image = await ImagePicker.pickImage(source: ImageSource.camera);
                  setState(() {
                    _image = image;
                  });
                  uploadAndScanImage();
                },),
                Container(height:20),
                InkWell(child: Column(children: <Widget>[Container(padding:EdgeInsets.all(12.0),child:Image.asset("images/photo_library.png"),width: 100),Container(child:Text("ギャラリーから選択",style:TEXT_STYLE),margin:EdgeInsets.only(top:8))],),onTap:() async {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                  var image = await ImagePicker.pickImage(source: ImageSource.gallery);
                  setState(() {
                    _image = image;
                  });
                  uploadAndScanImage();
                },),
              ],)),
              actions: <Widget>[
                FlatButton(
                    child: Text('閉じる'),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop('dialog');
                    })
              ]);
        });
  }

  void uploadAndScanImage() async {
    String filename = await uploadImage(_image);
    logger.d("filename:${filename}");
    if (filename == null) {
      showDialog(
          barrierDismissible: true,
          context: _context,
          builder: (_) {
            return AlertDialog(
                title: Text("アップロード失敗"),
                content: Text("写真のアップロードに失敗しました"),
                actions: <Widget>[
                  FlatButton(
                      child: Text('閉じる'),
                      onPressed: () =>
                          Navigator.of(_context, rootNavigator: true)
                              .pop('dialog'))
                ]);
          });
    } else {
      _s3filename = filename;
      ProgressDialog pr = ProgressDialog(context);
      pr.style(
        message: '読み込み中…',
        messageTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 16.0,
            fontWeight: FontWeight.normal),
      );
      pr.show();
      Map<String, dynamic> result;
      try {
        result = await getWineInfo(
            "https://grane.s3-ap-northeast-1.amazonaws.com/images/${filename}");
      }catch(e){
        logger.e(e);
      }
      pr.dismiss();
      if(result["name"]!=""){
        String exp = "ワイン名：${result["name"]}";
        if(result["varieties"].length!=0){
          List<String> varieties = result["varieties"];
          exp = "${exp}\n品種:${varieties.join(',')}";
        }
        showDialog(
            barrierDismissible: false,
            context: _context,
            builder: (_) {
              return AlertDialog(
                  title: Text("ワイン情報を取得しました"),
                  content: Text("取得したワイン情報を入力しますか？\n${exp}"),
                  actions: <Widget>[
                    FlatButton(
                        child: Text('いいえ'),
                        onPressed: () =>
                            Navigator.of(_context, rootNavigator: true)
                                .pop('dialog')),
                    FlatButton(
                        child: Text('はい'),
                        onPressed: () {
                          formKey.currentState.setName(result["name"]);
                          Navigator.of(_context, rootNavigator: true)
                              .pop('dialog');
                        })
                  ]);
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Material(
        child: Scaffold(
            appBar: AppBar(
              title: APP_BAR_LOGO,
              actions: <Widget>[
                FlatButton(
                    child: Text('記録', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      logger.i('AddEventState onPressed');
                      if (isPosting) {
                        return;
                      }
                      Map<String, dynamic> params =
                          formKey.currentState.getParams();
                      String subThumbFilename =
                          _s3filename;
                      String mainThumbFilename =
                          formMainThumbnailKey.currentState.getFilename();
                      logger.i("mainThumbFilename:${mainThumbFilename}");
                      if (subThumbFilename != null) {
                        params["etiquette"] =
                            "https://grane.s3-ap-northeast-1.amazonaws.com/images/${subThumbFilename}";
                      }
                      formKey.currentState.validate();
                      if (mainThumbFilename != null) {
                        params["image"] =
                            "https://grane.s3-ap-northeast-1.amazonaws.com/images/${mainThumbFilename}";
                      } else {
                        showErrorDialog("画像を選択してください");
                        return;
                      }
                      if (params["wine_name"] == null ||
                          params["wine_name"] == "") {
                        showErrorDialog("ワインの名称を入力してください");
                        return;
                      }
                      if (params["price_unit"] == null ||
                          params["price_unit"] == "") {
                        showErrorDialog("グラス/ボトルを選択してください");
                        return;
                      }
                      if (params["price"] == null || params["price"] == "") {
                        showErrorDialog("金額を入力してください");
                        return;
                      }
                      if (params["comment"] == null ||
                          params["comment"] == "") {
                        showErrorDialog("コメントを入力してください");
                        return;
                      }
                      isPosting = true;
                      ProgressDialog pr = ProgressDialog(context);
                      pr.style(
                        message: '投稿中…',
                        messageTextStyle: TextStyle(
                            color: Colors.black,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal),
                      );
                      pr.show();
                      String result = await addPost(params);
                      isPosting = false;
                      pr.dismiss();
                      showDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (_) {
                            return AlertDialog(
                                title:
                                    Text(result == "success" ? "投稿完了" : "投稿失敗"),
                                content: Text(result == "success"
                                    ? "投稿しました"
                                    : "投稿失敗しました\n時間をあけて再度送信してください"),
                                actions: <Widget>[
                                  FlatButton(
                                      child: Text('閉じる'),
                                      onPressed: () {
                                        if (result == "success") {
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .pop('dialog');
                                          Navigator.popUntil(
                                              context,
                                              ModalRoute.withName("/top"));
                                        } else {
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .pop('dialog');
                                        }
                                      })
                                ]);
                          });
                    })
              ],
            ),
            body: SingleChildScrollView(
                child: Stack(
              children: <Widget>[
                MainThumbnail(key: formMainThumbnailKey),
                Positioned(
                    top: 198,
                    left: 16.0,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                            top: 1,
                            left: 1,
                            child: CircleThumbnail(size: subImageSize - 2, file: _image)),
                        Container(
                            width: subImageSize,
                            height: subImageSize,
                            child: Container(
                                margin: EdgeInsets.all(1.0),
                                child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular((subImageSize - 2) / 2),
                                    child: Container(color: filter)))),
                        GestureDetector(
                            onTap: () {
                              showDialog(
                                  barrierDismissible: true,
                                  context: _context,
                                  builder: (_) {
                                    return GestureDetector(child:EtiquetteExp(),onTap:(){
                                      Navigator.of(_context, rootNavigator: true)
                                          .pop('dialog');
                                      getImage();
                                    },);
                                  });
                            },
                            onLongPress: (){
                              if(_image != null){
                                showDialog(
                                    barrierDismissible: true,
                                    context: _context,
                                    builder: (_) {
                                      return AlertDialog(
                                          title: Text("画像のリセット"),
                                          content: Text("選択した画像をリセットしますか？"),
                                          actions: <Widget>[
                                            FlatButton(
                                                child: Text('いいえ'),
                                                onPressed: () =>
                                                    Navigator.of(_context, rootNavigator: true)
                                                        .pop('dialog')),
                                            FlatButton(
                                                child: Text('はい'),
                                                onPressed: () {
                                                  _s3filename = null;
                                                  setState(() {
                                                    _image = null;
                                                  });
                                                  Navigator.of(_context,
                                                      rootNavigator: true)
                                                      .pop('dialog');
                                                })
                                          ]);
                                    });
                              }
                            },
                            child: Container(
                                width: subImageSize,
                                height: subImageSize,
                                decoration: BoxDecoration(
                                  border: Border.all(width: 3, color: Color(0xFFFFFFFF)),
                                  borderRadius: BorderRadius.circular(subImageSize / 2),
                                ),
                                child: Align(
                                    alignment: Alignment.center,
                                    child: Icon(Icons.image, color: Colors.white))))
                      ],
                    )),
                AddForm(key: formKey, restaurantData: restaurantData)
              ],
            ))));
  }
}

class AddForm extends StatefulWidget {
  const AddForm({Key key, this.restaurantData}) : super(key: key);
  final RestaurantData restaurantData;

  @override
  AddFormState createState() => AddFormState(restaurantData);
}

const List<String> wineVarieties = [
  'アギヨルギティコ',
  'アルバリーニョ',
  'ヴィオニエ',
  'ヴェルメンティーノ',
  'カベルネ・ソーヴィニヨン',
  'カベルネ・フラン',
  'ガメ',
  'カリニャン',
  'カルメネール',
  'クシノマヴロ',
  'グルナッシュ',
  'グレコ',
  'グレコ・ネロ',
  'ゲヴュルツトラミネール',
  'ケルナー',
  'コロンバール',
  '甲州',
  'サルタナ',
  'サンジョベーゼ',
  'シャルドネ',
  'シュナン・ブラン',
  'シラー',
  'ジンファンデル',
  'セミヨン',
  'ソーヴィニヨン・ブラン',
  'タナ',
  'ツヴァイゲルト',
  'テンプラニーリョ',
  'ドルペッジョ',
  'トレッビアーノ',
  'ネグロアマーロ',
  'ネッビオーロ',
  'ネロ・ダヴォラ',
  'バルベーラ',
  'ビジュノワール',
  'ピノ・グリ',
  'ピノ・ブラン',
  'ピノタージュ',
  'ピノ・ノワール',
  'フィアーノ',
  'プティ・ヴェルド',
  'ブラック・クィーン',
  'ボンビーノ・ビアンコ',
  'マスカット・ベーリーA',
  'マルヴァジーア',
  'マルベック',
  'ミュラー・トゥルガウ',
  'ムールヴェードル',
  'ムニエ',
  'ムロン・ド・ブルゴーニュ',
  'メルロー',
  'モスカート',
  'モンテプルチャーノ',
  'ヤマ・ソービニオン',
  'リースリング',
  'リボッラ・ジャッラ',
  'ルビー・カベルネ',
  'レフォスコ',
  'その他'
];

class AddFormState extends State<AddForm> {
  AddFormState(this.restaurantData);

  final wineNameController = TextEditingController();
  final priceController = TextEditingController();
  final commentController = TextEditingController();
  final tagController = TextEditingController();
  final validateKey = GlobalKey<FormState>();
  final RestaurantData restaurantData;
  FocusNode priceFocusNode;
  FocusNode tagFocusNode;
  List _myActivities;
  String _myActivitiesResult;

  @override
  void initState() {
    super.initState();

    priceFocusNode = FocusNode();
    tagFocusNode = FocusNode();
    _myActivities = [];
    _myActivitiesResult = '';
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    priceFocusNode.dispose();
    tagFocusNode.dispose();

    super.dispose();
  }

  void setName(name){
    setState(() {
      wineNameController.text = name;
    });
  }

  Map<String, dynamic> getParams() {
    final Map<String, dynamic> params = Map<String, dynamic>();
    if (country != "") {
      params["country_of_origin"] = country;
    }
    if (restaurantData != null) {
      params['restaurant'] = restaurantData.toJson();
    }
    params['wine_name'] = wineNameController.text;
    params['type'] = wineCategory;
    List<Map<String, dynamic>> varieties = List<Map<String, dynamic>>();
    params['varieties'] = varieties;
    if (wineVariety != null && wineVariety != "") {
      var variety = Map<String, dynamic>();
      variety["name"] = wineVariety;
      variety["main"] = 1;
      varieties.add(variety);
    }
    if (_myActivities.length > 0) {
      for (var i = 0; i < _myActivities.length; i++) {
        if (_myActivities[i] != null && _myActivities[i] != "") {
          var variety = Map<String, dynamic>();
          variety["name"] = _myActivities[i];
          variety["main"] = 0;
          varieties.add(variety);
        }
      }
    }

    params['price_unit'] = priceUnit;
    params['price'] = priceController.text;
    params['comment'] = commentController.text;
    params['place_tag'] = tagController.text;
    return params;
  }

  static const List<String> wineCategories = [
    'スパークリング',
    'シャンパン',
    '白ワイン',
    '赤ワイン',
    'アイスワイン',
    'デザートワイン',
    '貴腐ワイン',
  ];
  String wineCategory;
  String wineVariety;
  static const List<String> priceUnits = [
    'グラス',
    'ボトル',
    'ハーフボトル',
    'デカンタ',
    'フリー(飲み放題)',
  ];
  String priceUnit;

  static const List<String> countries = [
    'フランス',
    'イタリア',
    'アメリカ',
    'チリ',
    'アルゼンチン',
    'ニュージーランド',
    '日本',
    '中国',
    'オーストラリア',
    'ドイツ',
    'スペイン',
    'ポルトガル',
    'その他'
  ];
  String country;

  bool validate() {
    var result = validateKey.currentState.validate();
    logger.d("result:${result}");
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData expansionTileTheme = Theme.of(context).copyWith(dividerColor:Colors.transparent);
    var dataSource = [];
    for (var i = 0; i < wineVarieties.length; i++) {
      var map = Map<String, String>();
      map['display'] = wineVarieties[i];
      map['value'] = wineVarieties[i];
      dataSource.add(map);
    }
    return Form(
        key: validateKey,
        child: Container(
          margin: EdgeInsets.only(
              top: 302.0, left: 16.0, right: 16.0, bottom: 24.0),
          child: Column(
            children: <Widget>[
              FormItem(
                  childWidget: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          restaurantData != null
                              ? restaurantData.name
                              : "自宅など持ち帰り",
                          style: FORM_TEXT_STYLE))),
              FormItem(
                  childWidget: Align(
                alignment: Alignment.centerLeft,
                child: TextFormField(
                    controller: wineNameController,
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
                    style: FORM_TEXT_STYLE),
              )),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                        width: 160,
                        height: 64,
                        child: FormItem(
                            childWidget: DropdownStringButton(
                                items: priceUnits,
                                value: priceUnit,
                                hint: Container(
                                    margin: EdgeInsets.only(bottom: 0),
                                    child: Text(
                                      'グラス/ボトル',
                                    )),
                                onChanged: (value) {
                                  debugPrint(value);
                                  this.setState(() {
                                    priceUnit = value;
                                    FocusScope.of(context).requestFocus(priceFocusNode);
                                  });
                                })))),
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
                              controller: priceController,
                              validator: (value) {
                                if (value.isEmpty) {
                                  return "金額を入力してください";
                                }
                                return null;
                              },
                              maxLength: 7,
                              focusNode: priceFocusNode,
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
                    controller: commentController,
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
                  child: Theme(data:expansionTileTheme,child:ExpansionTile(
                      title: Text(
                        "詳しく書く",
                        style: TEXT_STYLE,
                      ),
                      children: <Widget>[
                        Column(children: <Widget>[
                          Container(
                              child: FormItem(
                                  childWidget: DropdownStringButton(
                                      items: countries,
                                      value: country,
                                      hint: Container(
                                          margin: EdgeInsets.only(bottom: 14),
                                          child: Text(
                                            'ワインの原産国',
                                          )),
                                      onChanged: (value) {
                                        FocusScope.of(context).requestFocus(FocusNode());
                                        debugPrint(value);
                                        this.setState(() {
                                          country = value;
                                        });
                                      }))),
                          Container(
                              margin: EdgeInsets.only(top: 16),
                              child: FormItem(
                                  childWidget: DropdownStringButton(
                                      items: wineCategories,
                                      value: wineCategory,
                                      hint: Container(
                                          margin: EdgeInsets.only(bottom: 14),
                                          child: Text(
                                            'ワインの種類',
                                          )),
                                      onChanged: (value) {
                                        FocusScope.of(context).requestFocus(FocusNode());
                                        debugPrint(value);
                                        this.setState(() {
                                          wineCategory = value;
                                        });
                                      }))),
                          Container(
                              margin: EdgeInsets.only(top: 10),
                              child: FormItem(
                                  childWidget: DropdownStringButton(
                                      value: wineVariety,
                                      items: wineVarieties,
                                      hint: Container(
                                          margin: EdgeInsets.only(bottom: 14),
                                          child: Text(
                                            '一番比率が高い葡萄の品種',
                                          )),
                                      onChanged: (value) {
                                        FocusScope.of(context).requestFocus(FocusNode());
                                        debugPrint(value);
                                        this.setState(() {
                                          wineVariety = value;
                                        });
                                      }))),
                          FormItem(childWidget: Form(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: MultiSelectFormField(
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
                                    value: _myActivities,
                                    onSaved: (value) {
                                      FocusScope.of(context).requestFocus(FocusNode());
                                      if (value == null) return;
                                      setState(() {
                                        FocusScope.of(context).requestFocus(tagFocusNode);
                                        _myActivities = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          )),
                          FormItem(
                              childWidget: Align(
                            alignment: Alignment.centerLeft,
                            child: TextFormField(
                                controller: tagController,
                                maxLines: 1,
                                focusNode: tagFocusNode,
                                decoration: new InputDecoration(
                                  border: const UnderlineInputBorder(),
                                  labelText: 'タグ',
                                  hintText: '東京,新宿'
                                ),
                                style: FORM_TEXT_STYLE),
                          )),
                        ])
                      ])))
            ],
          ),
        ));
  }
}

class CircleThumbnail extends StatelessWidget {
  const CircleThumbnail({
    Key key,
    this.size,
    this.file,
  }) : super(key: key);

  final double size;
  final File file;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: size,
        height: size,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
                color: Colors.white,
                child: file != null
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                      )
                    : Container())));
  }
}

class MainThumbnail extends StatefulWidget {
  const MainThumbnail({Key key}) : super(key: key);

  @override
  MainThumbnailState createState() => MainThumbnailState();
}

class MainThumbnailState extends State<MainThumbnail> {
  final double mainImageSize = 240.0;
  var _context;

  File _image;
  String _s3filename;

  String getFilename() {
    return _s3filename;
  }

  void uploadAndScanImage() async {
    String filename = await uploadImage(_image);
    logger.d("filename:${filename}");
    if (filename == null) {
      showDialog(
          barrierDismissible: true,
          context: _context,
          builder: (_) {
            return AlertDialog(
                title: Text("アップロード失敗"),
                content: Text("写真のアップロードに失敗しました"),
                actions: <Widget>[
                  FlatButton(
                      child: Text('閉じる'),
                      onPressed: () =>
                          Navigator.of(_context, rootNavigator: true)
                              .pop('dialog'))
                ]);
          });
    } else {
      _s3filename = filename;
    }
  }

  Future getImage() async {

    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (_) {
          return AlertDialog(
              title: Text("写真の取り込み"),
              content: Container(height:280,child:Column(children: <Widget>[
                InkWell(child: Column(children: <Widget>[Container(padding:EdgeInsets.all(12.0),child:Image.asset("images/photo_camera.png"),width: 100),Container(child:Text("カメラで撮影",style: TEXT_STYLE,),margin:EdgeInsets.only(top:8))],),onTap:() async {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                  var image = await ImagePicker.pickImage(source: ImageSource.camera);
                  setState(() {
                    _image = image;
                  });
                  uploadAndScanImage();
                },),
                Container(height:20),
                InkWell(child: Column(children: <Widget>[Container(padding:EdgeInsets.all(12.0),child:Image.asset("images/photo_library.png"),width: 100),Container(child:Text("ギャラリーから選択",style:TEXT_STYLE),margin:EdgeInsets.only(top:8))],),onTap:() async {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                  var image = await ImagePicker.pickImage(source: ImageSource.gallery);
                  setState(() {
                    _image = image;
                  });
                  uploadAndScanImage();
                },),
              ],)),
              actions: <Widget>[
                FlatButton(
                    child: Text('閉じる'),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop('dialog');
                    })
              ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Column(
      children: <Widget>[
        GestureDetector(
            onTap: () {
              getImage();
            },
            child: Container(
              height: mainImageSize,
              child: Stack(
                children: <Widget>[
                  Container(
                      child: Align(
                          alignment: Alignment.center,
                          child: SizedBox.expand(
                              child: _image != null
                                  ? Image.file(
                                      _image,
                                      fit: BoxFit.cover,
                                    )
                                  : Container()))),
                  Container(
                    height: mainImageSize,
                    color: filter,
                  ),
                  Container(
                    height: mainImageSize,
                    child: Align(
                        alignment: Alignment.center,
                        child: Icon(Icons.image, color: Colors.white)),
                  )
                ],
              ),
            ))
      ],
    );
  }
}

class DropdownStringButton extends DropdownButton<String> {
  DropdownStringButton({
    Key key,
    @required List<String> items,
    value,
    hint,
    disabledHint,
    @required onChanged,
    elevation = 8,
    style,
    iconSize = 24.0,
    isDense = false,
    isExpanded = true,
  })  : assert(items == null ||
            value == null ||
            items.where((String item) => item == value).length == 1),
        super(
          key: key,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
                child: Text(
                  item,
                  style: FORM_TEXT_STYLE,
                ),
                value: item);
          }).toList(),
          value: value,
          hint: hint,
          disabledHint: disabledHint,
          onChanged: onChanged,
          elevation: elevation,
          style: style,
          iconSize: iconSize,
          isDense: isDense,
          isExpanded: isExpanded,
        );
}
