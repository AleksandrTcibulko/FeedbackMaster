//
//  MainViewController.swift
//  FeedbackMaster
//
//  Created by Александр Цибулько on 15.03.2026.
//

import MessageUI
import PaperKit
import PencilKit
import Photos
import UIKit

final class MainViewController: UIViewController {

	@ViewLoading private var paperViewController: PaperMarkupViewController
	@ViewLoading private var toolPicker: PKToolPicker

	private var isPaperFirstResonder = true

	private lazy var emailButton: UIButton = {
		var config = UIButton.Configuration.filled()
		config.title = "Отправить"
		config.baseForegroundColor = .white
		let imageConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
		config.image = UIImage(systemName: "envelope", withConfiguration: imageConfig)
		config.imagePlacement = .leading
		config.imagePadding = 10
		config.baseBackgroundColor = .systemGreen
		config.cornerStyle = .medium
		let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
			self?.sendEmail()
		})
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()


	// MARK: Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .lightGray
		setupNavigationBar()
		setupBottomButton()

		paperViewController = PaperMarkupViewController(markup: PaperMarkup(bounds: .zero), supportedFeatureSet: .latest)
		addChild(paperViewController)
		paperViewController.didMove(toParent: self)

		paperViewController.view.backgroundColor = .lightGray
		view.addSubview(paperViewController.view)
		paperViewController.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			paperViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			paperViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			paperViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			paperViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
		])

		toolPicker = PKToolPicker()
		toolPicker.addObserver(paperViewController)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		paperViewController.markup?.bounds = paperViewController.view.bounds
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		paperViewController.becomeFirstResponder()
		toolPicker.setVisible(true, forFirstResponder: paperViewController)

		paperViewController.pencilKitResponderState.activeToolPicker = toolPicker
		paperViewController.pencilKitResponderState.toolPickerVisibility = .visible
	}

	// MARK: Buttons setup

	private func setupNavigationBar() {
		let importScreenshotButton = UIBarButtonItem(image: UIImage(systemName: "arrow.down.circle"),
													 style: .plain,
													 target: self,
													 action: #selector(importScreenshot))
		let clearButton = UIBarButtonItem(image: UIImage(systemName: "trash"),
										  style: .plain,
										  target: self,
										  action: #selector(clearDrawings))
		navigationItem.leftBarButtonItems = [importScreenshotButton, clearButton]
		navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "pencil.and.outline"),
															style: .plain,
															target: self,
															action: #selector(updateToolsVisibility))
	}

	private func setupBottomButton() {
		view.addSubview(emailButton)
		NSLayoutConstraint.activate([
			emailButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
			emailButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			emailButton.heightAnchor.constraint(equalToConstant: 50),
			emailButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
		])
	}

	// MARK: Actions

	@objc func importScreenshot() {
		loadLatestScreenshot()
	}

	@objc func clearDrawings() {
		paperViewController.markup = PaperMarkup(bounds: paperViewController.view.bounds)
	}

	@objc func updateToolsVisibility() {
		isPaperFirstResonder.toggle()

		if isPaperFirstResonder {
			paperViewController.becomeFirstResponder()
		} else {
			paperViewController.resignFirstResponder()
		}
	}

	@objc func sendEmail() {
		guard MFMailComposeViewController.canSendMail() else {
			print("Почта не настроена на устройстве")
			return
		}

		let mail = MFMailComposeViewController()
		mail.mailComposeDelegate = self
		mail.setSubject("Мой рисунок из PaperKit")
		mail.setToRecipients(["test@yandex.ru"])

		if let jpegData = getJPEGDataFromPaperKit(controller: paperViewController) {
			mail.addAttachmentData(jpegData, mimeType: "image/jpeg", fileName: "drawing.jpg")
		}

		present(mail, animated: true)
	}

	private func getJPEGDataFromPaperKit(controller: PaperMarkupViewController) -> Data? {
		let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
		let image = renderer.image { context in
			controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
		}
		return image.jpegData(compressionQuality: 0.8)
	}
}

// MARK: - MFMailComposeViewControllerDelegate
extension MainViewController: MFMailComposeViewControllerDelegate {

	func mailComposeController(
		_ controller: MFMailComposeViewController,
		didFinishWith result: MFMailComposeResult,
		error: Error?
	) {
		controller.dismiss(animated: true)
	}
}

// MARK: - Screenshot Loading
private extension MainViewController {

	func loadLatestScreenshot() {
		fetchLatestScreenshot { [weak self] image in
			guard let self, let image else { return }
			let imageView = UIImageView(image: image)
			imageView.contentMode = .scaleAspectFit
			paperViewController.contentView = imageView
		}
	}

	func fetchLatestScreenshot(completion: @escaping (UIImage?) -> Void) {
		// 1. Запрашиваем разрешение
		PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
			guard status == .authorized || status == .limited else {
				DispatchQueue.main.async {
					completion(nil)
				}
				return
			}

			// 2. Настраиваем поиск: сортировка по дате, только 1 последний объект
			let fetchOptions = PHFetchOptions()
			fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
			fetchOptions.fetchLimit = 1

			// 3. Ищем именно скриншоты (MediaSubtypePhotoScreenshot)
			let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

			// Ищем первый скриншот в результате
			var screenshotAsset: PHAsset?
			fetchResult.enumerateObjects { asset, _, stop in
				if asset.mediaSubtypes.contains(.photoScreenshot) {
					screenshotAsset = asset
					stop.pointee = true
				}
			}

			guard let asset = screenshotAsset else {
				DispatchQueue.main.async {
					completion(nil)
				}
				return
			}

			// 4. Загружаем само изображение
			let manager = PHImageManager.default()
			let options = PHImageRequestOptions()
			options.isSynchronous = false
			options.deliveryMode = .highQualityFormat
			options.resizeMode = .exact

			// Оптимальный размер для экрана
			let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
									height: UIScreen.main.bounds.height * UIScreen.main.scale)

			manager.requestImage(for: asset,
							   targetSize: targetSize,
							   contentMode: .aspectFit,
							   options: options) { image, info in

				// Проверяем, не thumbnail ли это
				let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
				if !isDegraded {
					DispatchQueue.main.async {
						completion(image)
					}
				}
			}
		}
	}
}
