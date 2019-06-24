import UIKit

internal final class UIImageViewEx {
    public var loader: URLImageLoader
    public var url: URL?
    public var urlImageHandler: ((UIImage?) -> Void)?
    public var showsSpinner: Bool
    public var spinner: UIActivityIndicatorView?
    
    public init(loader: URLImageLoader) {
        self.loader = loader
        self.showsSpinner = false
    }
}

internal var exKey: UInt8 = 0

extension UIImageView {
    internal var ex: UIImageViewEx {
        get {
            if let ex = objc_getAssociatedObject(self, &exKey) as? UIImageViewEx {
                return ex
            }
            
            let ex = makeEx()
            self.ex = ex
            return ex
        }
        set {
            objc_setAssociatedObject(self, &exKey, newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func makeEx() -> UIImageViewEx {
        let ex = UIImageViewEx(loader: URLImageLoader())
        ex.loader.imageHandler = { [weak self, weak ex] (image) in
            guard let self = self,
                let ex = ex else { return }

            self.image = image
            
            ex.urlImageHandler?(image)
        }
        ex.loader.isLoadingHandler = { [weak self, weak ex] (isLoading) in
            guard let self = self,
                let ex = ex else { return }
            
            if isLoading, ex.showsSpinner {
                self.showSpinner()
            } else {
                self.hideSpinner()
            }
        }
        return ex
    }
    
    public var url: URL? {
        get { return ex.url }
        set {
            let ex = self.ex
            let oldValue = self.url
            ex.url = newValue
            
            func needsStart() -> Bool {
                if oldValue != newValue {
                    return true
                }
                
                if let _ = newValue,
                    ex.loader.image == nil
                {
                    return true
                }
                
                return false
            }
            
            if needsStart() {
                ex.loader.url = newValue
                ex.loader.start()
            }
        }
    }
    
    public var urlImageHandler: ((UIImage?) -> Void)? {
        get { return ex.urlImageHandler }
        set { ex.urlImageHandler = newValue }
    }
    
    public var showsSpinner: Bool {
        get { return ex.showsSpinner }
        set { ex.showsSpinner = newValue }
    }
    
    private func showSpinner() {
        if let _ = ex.spinner { return }
        
        let spinner = UIActivityIndicatorView(style: .gray)
        ex.spinner = spinner
        
        spinner.startAnimating()
        
        self.addSubview(spinner)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    
    private func hideSpinner() {
        guard let spinner = ex.spinner else {
            return
        }
        
        spinner.removeFromSuperview()
        ex.spinner = nil
    }
    
}
