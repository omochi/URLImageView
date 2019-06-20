import UIKit

internal final class UIImageViewEx {
    public var loader: URLImageLoader
    public var url: URL?
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
        ex.loader.imageHandler = { [weak self] (image) in
            guard let self = self else { return }
            
            self.image = image            
        }
        ex.loader.isLoadingHandler = { [weak self] (isLoading) in
            guard let self = self else { return }
            
            if isLoading {
                self.showSpinner()
            } else {
                self.hideSpinner()
            }
        }
        return ex
    }
    
    public var url: URL? {
        get {
            return ex.url
        }
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
