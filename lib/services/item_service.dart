import 'api_service.dart';

class ItemService {
  final _api = ApiService();

  Future getItems() => _api.getRequest('/items/');
}
