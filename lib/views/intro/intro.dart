import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:Tether/domain/index.dart';
import 'package:Tether/domain/user/model.dart';

import 'package:touchable_opacity/touchable_opacity.dart';

class IntroScreen extends StatelessWidget {
  IntroScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double DEFAULT_INPUT_HEIGHT = 52;
    double DEFAULT_BUTTON_HEIGHT = 48;

    return Scaffold(
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(height: height * 0.05),
          Container(
            width: width * 0.7,
            height: DEFAULT_INPUT_HEIGHT,
            constraints:
                BoxConstraints(minWidth: 200, maxWidth: 400, minHeight: 200),
            child: SvgPicture.asset('assets/graphics/undraw_mobile_user.svg',
                semanticsLabel: 'Relaxed, Lounging User'),
          ),
          SizedBox(height: height * 0.025),
          Text(
            'Welcome to Tether',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.display1,
          ),
          SizedBox(height: height * 0.025),
          Text(
            'Take back your privacy and freedom \nwithout the hassle.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.subtitle,
          ),
          SizedBox(height: height * 0.15),
          StoreConnector<AppState, UserStore>(
            converter: (Store<AppState> store) => store.state.userStore,
            builder: (context, userStore) {
              return Container(
                width: width * 0.7,
                height: DEFAULT_BUTTON_HEIGHT,
                margin: const EdgeInsets.all(10.0),
                constraints:
                    BoxConstraints(minWidth: 200, maxWidth: 400, minHeight: 45),
                child: FlatButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  color: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: new BorderRadius.circular(30.0)),
                  child: const Text('Let\'s Go',
                      style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              );
            },
          ),
        ],
      )),
    );
  }
}
