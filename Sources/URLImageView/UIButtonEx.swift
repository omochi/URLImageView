import UIKit

internal final class UIButtonEx : ExProtocol {
    public struct StateProperties {
        public let url: URLImageProperty
    }
    
    public static let states: [UIButton.State] = [
        .normal,
        .highlighted,
        .selected,
        .disabled
    ]
    
    public unowned let view: UIButton
    public var stateProperties: [UInt: StateProperties] = [:]
    public var urlImageHandler: ((UIButton.State, UIImage?) -> Void)?
    public var showsURLSpinner: Bool = false
    public var spinner: UIActivityIndicatorView?
    public var isURLLoading: Bool = false {
        didSet {
            if oldValue == isURLLoading { return }
            
            if isURLLoading, showsURLSpinner {
                view.showSpinnerIfNeed(spinner: &spinner)
            } else {
                view.hideSpinner(spinner: &spinner)
            }
            
            isURLLoadingHandler?(isURLLoading)
        }
    }
    public var isURLLoadingHandler: ((Bool) -> Void)?
    
    public init(view: UIView) {
        self.view = view as! UIButton
        
        for state in UIButtonEx.states {
            let url = URLImageProperty()
            
            url.isLoadingHandler = { [weak self] (_) in
                guard let self = self else { return }
                
                self.isURLLoading = self.stateProperties.values.contains { $0.url.isLoading }
            }
            url.imageHandler = { [weak self] (image) in
                guard let self = self else { return }
                
                self.view.setImage(image, for: state)
                
                self.urlImageHandler?(state, image)
            }
            
            let props = StateProperties(url: url)
            self.stateProperties[state.rawValue] = props
        }
    }
    
    private func normalize(state: UIButton.State) -> [UIButton.State] {
        var results: [UIButton.State] = []
        if state.contains(.highlighted) {
            results.append(.highlighted)
        }
        if state.contains(.disabled) {
            results.append(.disabled)
        }
        if state.contains(.selected) {
            results.append(.selected)
        }
        if results.isEmpty, state.contains(.normal) {
            results.append(.normal)
        }
        return results
    }

    public func url(for state: UIButton.State) -> URL? {
        guard let state = normalize(state: state).first else { return nil }
        
        return stateProperties[state.rawValue]?.url.url
    }
    
    public func setURL(for state: UIButton.State, _ url: URL?) {
        for state in normalize(state: state) {
            stateProperties[state.rawValue]?.url.url = url
        }
    }
    
    public func urlImage(for state: UIButton.State) -> UIImage? {
        guard let state = normalize(state: state).first else { return nil }
        
        return stateProperties[state.rawValue]?.url.image
    }
    
    public func setURLImage(for state: UIButton.State, _ image: UIImage?) {
        for state in normalize(state: state) {
            stateProperties[state.rawValue]?.url.image = image
        }
    }
    
    public func imageFilter(for state: UIButton.State) -> ((UIImage?) -> UIImage?)? {
        guard let state = normalize(state: state).first else { return nil }
        
        return stateProperties[state.rawValue]?.url.imageFilter
    }
    
    public func setImageFilter(for state: UIButton.State, _ filter: ((UIImage?) -> UIImage?)?) {
        for state in normalize(state: state) {
            stateProperties[state.rawValue]?.url.imageFilter = filter
        }
    }
    
    public func renderURLImage() {
        for state in UIButtonEx.states {
            stateProperties[state.rawValue]?.url.render()
        }
    }
}

extension UIButton {
    internal var ex: UIButtonEx { return exImpl() }

    public func url(for state: UIButton.State) -> URL? {
        return ex.url(for: state)
    }
    
    public func setURL(for state: UIButton.State, _ url: URL?) {
        ex.setURL(for: state, url)
    }
    
    public func urlImage(for state: UIButton.State) -> UIImage? {
        return ex.urlImage(for: state)
    }
    
    public func setURLImage(for state: UIButton.State, _ image: UIImage?) {
        ex.setURLImage(for: state, image)
    }
    
    public var urlImageHandler: ((UIButton.State, UIImage?) -> Void)? {
        get { return ex.urlImageHandler }
        set { ex.urlImageHandler = newValue }
    }
    
    public func imageFilter(for state: UIButton.State) -> ((UIImage?) -> UIImage?)? {
        return ex.imageFilter(for: state)
    }
    
    public func setImageFilter(for state: UIButton.State, _ filter: ((UIImage?) -> UIImage?)?) {
        ex.setImageFilter(for: state, filter)
    }
    
    public var isURLLoading: Bool { return ex.isURLLoading }

    public var isURLLoadingHandler: ((Bool) -> Void)? {
        get { return ex.isURLLoadingHandler }
        set { ex.isURLLoadingHandler = newValue }
    }
    
    @IBInspectable
    public var showsURLSpinner: Bool {
        get { return ex.showsURLSpinner }
        set { ex.showsURLSpinner = newValue }
    }
    
    public func renderURLImage() {
        ex.renderURLImage()
    }
}
