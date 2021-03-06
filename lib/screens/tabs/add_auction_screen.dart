import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:multi_image_picker/multi_image_picker.dart';
import 'package:provider/provider.dart';
import 'package:subbi/apis/server_api.dart';
import 'package:subbi/models/user.dart';
import 'package:subbi/others/error_logger.dart';
import 'package:subbi/screens/unauthenticated_box.dart';

import '../main_screen.dart';

class AddAuctionScreen extends StatefulWidget {
  @override
  _State createState() => _State();
}

class _State extends State<AddAuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categories = getCategories();

  User _user;
  String _category;
  String _name;
  String _description;
  int _quantity;
  double _initialPrice;
  bool _autovalidate = false;
  final int _descLength = 350;
  final int _nameLength = 80;
  int _state = 0;

  static const MAX_IMAGES = 6;
  List<Asset> images = List<Asset>();
  int _availableImages = MAX_IMAGES;

  @override
  Widget build(BuildContext context) {
    _user = Provider.of<User>(context);

    if (!_user.isSignedIn()) return UnauthenticatedBox();
    return Scaffold(
        appBar: AppBar(
          title: Text('Enviar lote'),
          leading: Icon(Icons.description),
        ),
        body: SingleChildScrollView(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            child: Builder(
              builder: (context) => Form(
                key: _formKey,
                autovalidate: _autovalidate,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _category,
                        hint: Text('Elija una categoría'),
                        icon: Icon(Icons.arrow_downward),
                        iconSize: 24,
                        elevation: 16,
                        style: TextStyle(
                          color: Colors.deepPurple,
                        ),
                        onChanged: (String newValue) {
                          setState(() {
                            _category = newValue;
                          });
                        },
                        validator: (value) => value != null
                            ? null
                            : "Categoria no puede ser vacía",
                        items: _categories
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextFormField(
                        maxLength: _nameLength,
                        decoration: InputDecoration(
                          hintText: "Inserte el título del lote",
                          labelText: "Título",
                        ),
                        onChanged: (String newValue) {
                          setState(() {
                            _name = newValue;
                          });
                        },
                        validator: (value) =>
                            value.isEmpty ? "Nombre no puede ser vacío" : null,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextFormField(
                        maxLines: 3,
                        maxLength: _descLength,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: "Inserte la descripción del lote",
                          labelText: "Descripción",
                        ),
                        onChanged: (String newValue) {
                          setState(() {
                            _description = newValue;
                          });
                        },
                        validator: (value) => value.isEmpty
                            ? "Descripción no puede ser vacío"
                            : null,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        decoration: InputDecoration(
                          hintText:
                              "Inserte la cantidad de artículos en su lote",
                          labelText: "Cantidad",
                        ),
                        onChanged: (String newValue) {
                          setState(() {
                            if (newValue.isNotEmpty) {
                              _quantity = int.parse(newValue);
                            }
                          });
                        },
                        validator: (value) => (value.isEmpty ||
                                (value.isNotEmpty && int.parse(value) <= 0))
                            ? "Cantidad debe ser un número entero mayor a cero"
                            : null,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextFormField(
                        initialValue: null,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          icon: Icon(Icons.monetization_on,
                              color: Theme.of(context).primaryColor),
                          isDense: true,
                          hintText: "Inserte su precio deseado",
                          labelText: "Precio inicial",
                        ),
                        onChanged: (String newValue) {
                          setState(() {
                            if (newValue.isNotEmpty) {
                              _initialPrice = double.parse(newValue);
                            }
                          });
                        },
                        validator: (value) => (value.isEmpty ||
                                (value.isNotEmpty && int.parse(value) <= 0))
                            ? "Precio inicial debe ser un numero mayor a cero"
                            : null,
                      ),
                    ),
                    Text(
                      'Incluya fotos del producto (al menos 3)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 17,
                      ),
                    ),
                    buildGridView(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[_buildSendLotButton()],
                    )
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  static List<String> getCategories() {
    return <String>[
      'Música',
      'Vehículos clásicos',
      'Consolas y Videojuegos',
      'Juguetes y modelos a escala',
      'Joyería y Relojes',
      'Peliculas y Series',
      'Antigüedades',
      'Muebles'
    ].toList();
  }

  Future<void> getImages() async {
    List<Asset> resultList;

    try {
      resultList = await MultiImagePicker.pickImages(
        maxImages: _availableImages,
        enableCamera: true,
      );
    } on Exception catch (e) {
      ErrorLogger.log(
        error: e.toString(),
        context: "Selecting images at add auction screen",
      );
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      images.addAll(resultList);
      _availableImages -= resultList.length;
    });
  }

  Widget buildGridView() {
    if (images != null) {
      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1,
        shrinkWrap: true,
        children: List.generate(MAX_IMAGES, (index) {
          if ((MAX_IMAGES - _availableImages) > index) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: <Widget>[
                  AssetThumb(
                    asset: images[index],
                    height: 300,
                    width: 300,
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: InkWell(
                      child: Icon(Icons.remove_circle,
                          size: 20, color: Colors.red),
                      onTap: () {
                        setState(() {
                          images.removeAt(index);
                          _availableImages++;
                        });
                      },
                    ),
                  )
                ],
              ),
            );
          } else {
            return Card(
              child: IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  getImages();
                },
              ),
            );
          }
        }),
      );
    } else {
      return Container();
    }
  }

  Widget _buildSendLotButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        //Wrap with Material
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0)),
        elevation: 8.0,
        color: Colors.deepPurple,
        clipBehavior: Clip.antiAlias, // Add This
        child: MaterialButton(
          minWidth: 200.0,
          height: 35,
          color: Colors.deepPurple,
          child: setUpButtonChild(),
          onPressed: _state != 0
              ? null
              : () async {
                  if (_formKey.currentState.validate()) {
                    if (images.length >= 3) {
                      setState(() {
                        if (_state == 0) {
                          _changeState(1);
                        }
                      });

                      List<int> imgIds = List<int>();

                      for (Asset image in images) {
                        int id = await ServerApi.instance().postPhoto(image);

                        imgIds.add(id);
                      }

                      await ServerApi.instance().postLot(
                        title: _name,
                        category: _category,
                        description: _description,
                        initialPrice: _initialPrice,
                        quantity: _quantity,
                        imgIds: imgIds,
                      );

                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.check_circle,
                                    size: 50,
                                    color: Colors.green,
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 0, 0, 5),
                                    child: Text(
                                      'Su lote fue enviado con exito!',
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.deepPurple),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      'En breve será revisado por nuestros expertos.',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.deepPurple),
                                    ),
                                  ),
                                ],
                              ),
                              actions: <Widget>[
                                RaisedButton(
                                  onPressed: () {
                                    DefaultTabController.of(context)
                                        .animateTo(MainScreen.HOME_TAB);
                                  },
                                  child: Text('ENTENDIDO'),
                                )
                              ],
                            );
                          });
                      _changeState(2);
                    } else {
                      final imagesErrorSnackbar = SnackBar(
                        content: Text(
                            'Deben incluir al menos 3 fotos, pruebe nuevamente.'),
                        action: SnackBarAction(
                          label: 'Cerrar',
                          onPressed: () {
                            Scaffold.of(context).hideCurrentSnackBar();
                          },
                        ),
                      );
                      Scaffold.of(context).showSnackBar(imagesErrorSnackbar);
                    }
                  } else {
                    setState(() {
                      _autovalidate = true; //enable realtime validation
                    });
                  }
                },
        ),
      ),
    );
  }

  void _changeState(state) {
    setState(() {
      _state = state;
    });
  }

  Widget setUpButtonChild() {
    if (_state == 0) {
      return Text(
        "Enviar lote".toUpperCase(),
        style: TextStyle(
          fontSize: 12,
        ),
      );
    } else if (_state == 1) {
      return CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      );
    } else {
      return Icon(Icons.check, color: Colors.white);
    }
  }
}
