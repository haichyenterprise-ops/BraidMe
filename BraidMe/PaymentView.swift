import SwiftUI

struct PaymentView: View {
    let braider: Braider
    let selectedStyle: String
    @State private var selectedDate = Date()
    @State private var showConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Circular Image
                Image(systemName: "photo")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.primary, lineWidth: 4))
                    .padding(.top, 30)
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 10)
                
                Text(selectedStyle)
                    .font(.title.bold())
                
                // Additional Options
                VStack(alignment: .leading, spacing: 15) {
                    Text("Additional Options")
                        .font(.headline)
                    Toggle("Add Beads", isOn: .constant(false))
                    Toggle("Hair Included", isOn: .constant(true))
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
                .padding(.horizontal)
                
                // Calendar
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Date")
                        .font(.headline)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppTheme.primary)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
                .padding(.horizontal)
                
                // Apple Pay Button
                Button(action: {
                    FirebaseManager.shared.createBooking(braiderName: braider.name, date: selectedDate, style: selectedStyle) { success in
                        if success {
                            showConfirmation = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Pay with Apple Pay")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Confirm Booking")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Booking Confirmed!", isPresented: $showConfirmation) {
            Button("Back to Home") {
                dismiss()
            }
        } message: {
            Text("Your booking with \(braider.name) for \(selectedStyle) on \(selectedDate.formatted(date: .abbreviated, time: .omitted)) is confirmed.")
        }
    }
}