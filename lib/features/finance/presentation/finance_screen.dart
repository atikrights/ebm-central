import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 32),
            Text('Recent Transactions', 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
              )),
            const SizedBox(height: 16),
            _buildTransactionList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return GlassCard(
      gradientColors: [
        const Color(0xFF0B6E4F).withOpacity(0.8),
        const Color(0xFF83D7B1).withOpacity(0.4),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Balance (Profit)', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Icon(Icons.account_balance_wallet, color: Colors.white.withOpacity(0.8)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '\$124,500.00',
            style: TextStyle(fontFamily: 'Manrope', fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _financeStat('Income', '\$145,200', Icons.arrow_upward, Colors.white),
              Container(width: 1, height: 40, color: Colors.white24),
              _financeStat('Expense', '\$20,700', Icons.arrow_downward, const Color(0xFFFF8C42)),
            ],
          )
        ],
      ),
    );
  }

  Widget _financeStat(String label, String amount, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 8,
      itemBuilder: (context, index) {
        final isCredit = index % 2 != 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D2F) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCredit ? const Color(0xFF3CB371).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit ? Icons.download : Icons.upload,
                  color: isCredit ? const Color(0xFF3CB371) : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCredit ? 'Client Payment' : 'Server Hosting',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold, 
                        fontSize: 16
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today, 10:4${index} AM',
                      style: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                isCredit ? '+\$4,500' : '-\$120',
                style: TextStyle(
                  color: isCredit ? const Color(0xFF3CB371) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
