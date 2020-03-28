# flutter-bloctest
FlutterでのBLoCパターン
  
graneというワイン記録・共有アプリの投稿画面をBLoCパターンを使用した時のレイアウト部分のコードを公開します。
https://grane.jp/
  
表示される画面イメージはこんな感じです。  
<img src="https://user-images.githubusercontent.com/13136853/77819328-6f172700-711d-11ea-9516-3f1b489e74fc.png" alt="attach:cat" title="attach:cat" width="300">

主要部分の実装がこんな感じで収まっています
```
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

