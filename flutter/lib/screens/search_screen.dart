import 'package:flutter/material.dart';
import '../controllers/view_controller.dart';
import '../widgets/map_view.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewController,
      builder: (_, __) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Search",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const [
                          Chip(label: Text("Breakfast")),
                          SizedBox(width: 8),
                          Chip(label: Text("Dinner")),
                          SizedBox(width: 8),
                          Chip(label: Text("Fast food")),
                          SizedBox(width: 8),
                          Chip(label: Text("Sushi")),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: viewController.isMap
                    ? const MapView()
                    : const ListViewWidget(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ListViewWidget extends StatelessWidget {
  const ListViewWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text("Offer card"),
      ),
    );
  }
}