//
//  ViewController.swift
//  original1
//
//  Created by Shiyori Matsuyama on 2025/06/29.
//


// ① ユーザーが画像を撮影（UIImage）
// ↓
// ② Visionフレームワークで文字認識（テキストを抽出）
// ↓
// ③ そのテキストを検索ワードとして使い、データベースをリクエスト
// ↓
// ④ 該当動画が見つかれば再生画面に遷移して表示


import UIKit
import Vision
import FirebaseCore
import FirebaseFirestore
import AVKit

class CameraViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var cameraButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        cameraButton.setTitle("撮影", for: .normal)
        cameraButton.layer.cornerRadius = 10
        cameraButton.backgroundColor = .systemBlue
        cameraButton.setTitleColor(.white, for: .normal)

    }

    // MARK: - カメラ起動
    @IBAction func cameraButtonTapped(_ sender: UIButton) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("カメラが使用できません")
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.allowsEditing = false
        present(picker, animated: true, completion: nil)
    }

    // MARK: - 撮影完了時
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        if let image = info[.originalImage] as? UIImage {
            recognizeText(from: image) { recognizedText in
                print("認識テキスト: \(recognizedText)")
                self.searchVideo(for: recognizedText) { videoURL in
                    if let url = videoURL {
                        self.playVideo(from: url)
                    } else {
                        self.showAlert(title: "動画が見つかりません", message: "関連する解説動画がありませんでした。")
                    }
                }
            }
        }
    }

    // MARK: - OCR
    func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }

            let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            completion(texts.joined(separator: " "))
        }

        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    // MARK: - Firebase検索
    func searchVideo(for keyword: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        let words = keyword.components(separatedBy: .whitespaces)

        var foundURL: String? = nil
        let group = DispatchGroup()

        for word in words {
            group.enter()
            db.collection("videos").whereField("keywords", arrayContains: word).getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first,
                   let url = doc["videoURL"] as? String {
                    foundURL = url
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(foundURL)
        }
    }

    // MARK: - 動画再生
    func playVideo(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let player = AVPlayer(url: url)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        present(playerVC, animated: true) {
            player.play()
        }
    }

    // MARK: - アラート表示
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // 撮影キャンセル時
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
