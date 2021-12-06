// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveCore
import ComposableArchitecture

struct OnboardingState: Equatable {
  enum Path: Equatable {
    case create(CreatePathStep)
    case restore
  }
  enum CreatePathStep: Int {
    case createWallet
    case backupWelcome
    case backupPhrase
    case verifyPhrase
    
    var next: Self? {
      .init(rawValue: rawValue + 1)
    }
    var previous: Self? {
      .init(rawValue: rawValue - 1)
    }
  }
  var path: Path?
  var recoveryPhrase: String?
}

enum OnboardingAction {
  case moveForward
  case fetchRecoveryPhrase
  case recoveryPhraseFetched(String)
  case setupButtonTapped
  case restoreButtonTapped
}

struct OnboardingEnvironment {
  var keyringController: BraveWalletKeyringController
}

let onboardingReducer = Reducer<
  OnboardingState, OnboardingAction, OnboardingEnvironment
> { state, action, environment in
  switch action {
  case .moveForward:
    return .none
  case .fetchRecoveryPhrase:
    return .future { callback in
      environment
        .keyringController.mnemonic { phrase in
          callback(.success(.recoveryPhraseFetched(phrase)))
        }
    }
  case .recoveryPhraseFetched(let phrase):
    state.recoveryPhrase = phrase
    return .none
  case .setupButtonTapped:
    state.path = .create(.createWallet)
    return .none
  case .restoreButtonTapped:
    state.path = .restore
    return .none
  }
}

import BraveUI
import SwiftUI
import struct Shared.Strings
import Introspect

struct TcaWelcomeView: View {
  let store: Store<OnboardingState, OnboardingAction>
  @ObservedObject var viewStore: ViewStore<OnboardingState, OnboardingAction>
  
  init(store: Store<OnboardingState, OnboardingAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
  }
  
  var body: some View {
    VStack(spacing: 46) {
      Image("setup-welcome")
      VStack(spacing: 14) {
        Text(Strings.Wallet.setupCryptoTitle)
          .foregroundColor(.primary)
          .font(.headline)
        Text(Strings.Wallet.setupCryptoSubtitle)
          .foregroundColor(.secondary)
          .font(.subheadline)
      }
      .fixedSize(horizontal: false, vertical: true)
      .multilineTextAlignment(.center)
      VStack(spacing: 26) {
        NavigationLink(
          isActive: viewStore.binding(
            get: { (/OnboardingState.Path.create).extract(from: $0.path) != nil },
            send: .setupButtonTapped
          )
        ) {
          EmptyView()
        } label: {
          Text(Strings.Wallet.setupCryptoButtonTitle)
        }
        .buttonStyle(BraveFilledButtonStyle(size: .normal))
//        NavigationLink(
//          destination: RestoreWalletContainerView(keyringStore: keyringStore)
//        ) {
//          Text(Strings.Wallet.restoreWalletButtonTitle)
//            .font(.subheadline.weight(.medium))
//            .foregroundColor(Color(.braveLabel))
//        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityEmbedInScrollView()
    .navigationTitle(Strings.Wallet.cryptoTitle)
    .navigationBarTitleDisplayMode(.inline)
    .introspectViewController { vc in
      vc.navigationItem.backButtonTitle = Strings.Wallet.setupCryptoButtonBackButtonTitle
      vc.navigationItem.backButtonDisplayMode = .minimal
    }
    .background(Color(.braveBackground).edgesIgnoringSafeArea(.all))
  }
}


