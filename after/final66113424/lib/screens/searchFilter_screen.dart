import 'package:final66113424/helpers/database_helper.dart';
import 'package:final66113424/screens/incidentDetail_screen.dart';
import 'package:flutter/material.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _severityOptions = ['ทั้งหมด', 'High', 'Medium', 'Low'];

  String _selectedSeverity = 'ทั้งหมด';
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _applySearchFilter();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _applySearchFilter() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await searchAndFilterIncidents(
        keyword: _searchController.text,
        severity: _selectedSeverity,
      );

      if (!mounted) return;
      setState(() {
        _results = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailScreen(report: report),
      ),
    );

    if (!mounted) return;
    await _applySearchFilter();
  }
  

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _applySearchFilter(),
      decoration: InputDecoration(
        labelText: 'ค้นหา: ชื่อผู้แจ้ง หรือ รายละเอียด',
        hintText: 'พิมพ์คำค้น เช่น พลเมืองดี, แจกเงิน',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: _applySearchFilter,
          tooltip: 'ค้นหา',
        ),
      ),
    );
  }

  Widget _buildSeverityDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSeverity,
      decoration: const InputDecoration(
        labelText: 'ความรุนแรง (Severity)',
        border: OutlineInputBorder(),
      ),
      items: _severityOptions
          .map(
            (value) => DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedSeverity = value);
        _applySearchFilter();
      },
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No records found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final report = _results[index];
        final reporterName = report['reporter_name']?.toString() ?? '-';
        final description = report['description']?.toString() ?? '-';
        final severity = report['severity']?.toString() ?? '-';
        final violationName = report['violation_name']?.toString() ?? '-';

        return ListTile(
          onTap: () => _openReportDetail(report),
          title: Text(
            reporterName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(violationName),
              Text('Severity: $severity'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search & Filter')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildSeverityDropdown(),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }
}
