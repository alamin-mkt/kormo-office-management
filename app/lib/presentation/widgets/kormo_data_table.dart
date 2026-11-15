import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class KormoDataTableColumn {
  final String label;
  final bool isNumeric;
  final double? width;

  const KormoDataTableColumn({
    required this.label,
    this.isNumeric = false,
    this.width,
  });
}

class KormoDataTable extends StatefulWidget {
  final String title;
  final List<KormoDataTableColumn> columns;
  final List<List<Widget>> rows;
  final bool isLoading;
  final Widget? trailingAction;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportPdf;
  final ValueChanged<String>? onSearchChanged;

  const KormoDataTable({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.trailingAction,
    this.onExportCsv,
    this.onExportPdf,
    this.onSearchChanged,
  });

  @override
  State<KormoDataTable> createState() => _KormoDataTableState();
}

class _KormoDataTableState extends State<KormoDataTable> {
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalRows = widget.rows.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage > totalRows) ? totalRows : startIndex + _rowsPerPage;
    final pageRows = totalRows > 0 ? widget.rows.sublist(startIndex, endIndex) : <List<Widget>>[];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header Bar (Search & Export Buttons)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.onSearchChanged != null)
                      SizedBox(
                        width: 220,
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          onChanged: widget.onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    if (widget.onExportCsv != null)
                      OutlinedButton.icon(
                        onPressed: widget.onExportCsv,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('CSV'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(60, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    if (widget.onExportPdf != null)
                      OutlinedButton.icon(
                        onPressed: widget.onExportPdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(60, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    if (widget.trailingAction != null) widget.trailingAction!,
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // Table Content
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
            )
          else if (totalRows == 0)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('No records found', style: TextStyle(color: AppColors.muted)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                columns: widget.columns.map((c) {
                  return DataColumn(
                    label: Text(c.label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted)),
                    numeric: c.isNumeric,
                  );
                }).toList(),
                rows: pageRows.map((cells) {
                  return DataRow(
                    cells: cells.map((cell) => DataCell(cell)).toList(),
                  );
                }).toList(),
              ),
            ),

          const Divider(),

          // Pagination Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalRows == 0 ? 0 : startIndex + 1} - $endIndex of $totalRows entries',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text(
                      'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
