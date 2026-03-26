//
//  LogoSettingsSectionView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 26/03/2026.
//

import PhotosUI
import SwiftUI
import TablerIcons

struct LogoSettingsSectionView: View {
  @ObservedObject var viewModel: LogoSettingsViewModel
  @State private var selectedPhotoItem: PhotosPickerItem?

  private let primaryColor = Color("PrimaryColor")

  var body: some View {
    VStack(alignment: .leading) {
      Text("Logo")
        .font(SofiaFont.semiBold(size: 18))
        .foregroundStyle(.primary)

      VStack {
        HStack(alignment: .center, spacing: 12) {
          if let image = viewModel.model.logoImage {
            Button {
              viewModel.presentDeleteConfirmation()
            } label: {
              ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                  .resizable()
                  .scaledToFill()
                  .frame(width: 64, height: 64)
                  .clipShape(RoundedRectangle(cornerRadius: 16))

                Image(systemName: "trash.fill")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.white)
                  .padding(6)
                  .background(Color.black.opacity(0.45))
                  .clipShape(Circle())
                  .padding(6)
              }
            }
            .buttonStyle(.plain)
          } else {
            PhotosPicker(
              selection: $selectedPhotoItem,
              matching: .images
            ) {
              ZStack {
                Image(uiImage: TablerIcons.plusOutlined)
                  .renderingMode(.template)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 24, height: 24)
                  .foregroundStyle(.white)
              }
              .frame(width: 64, height: 64)
              .background(primaryColor)
              .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
          }

          Text(viewModel.model.logoImage == nil ? "Add Logo" : "Your logo")
            .font(SofiaFont.semiBold(size: 16))
            .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: 400, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
      }
    }
    .onChange(of: selectedPhotoItem) { _, newItem in
      guard let newItem else { return }
      Task {
        let data = try? await newItem.loadTransferable(type: Data.self)
        await MainActor.run {
          selectedPhotoItem = nil
          if let data {
            viewModel.importPhoto(data: data)
          }
        }
      }
    }
    .alert("Delete logo?", isPresented: $viewModel.showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        viewModel.deleteLogo()
      }
    } message: {
      Text("Your saved logo will be removed from this device.")
    }
  }
}

#Preview {
  LogoSettingsSectionView(viewModel: LogoSettingsViewModel())
    .padding()
}
