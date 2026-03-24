use std::ffi::c_void;
use std::slice;
use webrtc_audio_processing::config::{
    EchoCanceller, HighPassFilter,
};
use webrtc_audio_processing::{Config, Error, Processor};

struct AecState {
    processor: Processor,
    frame_size: usize,
}

fn error_code(error: Error) -> i32 {
    match error {
        Error::Unspecified => -1,
        Error::InitializationFailed => -2,
        Error::UnsupportedComponent => -3,
        Error::UnsupportedFunction => -4,
        Error::NullPointer => -5,
        Error::BadParameter => -6,
        Error::BadSampleRate => -7,
        Error::BadDataLength => -8,
        Error::BadNumberChannels => -9,
        Error::File => -10,
        Error::StreamParameterNotSet => -11,
        Error::NotEnabled => -12,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn aec_create(sample_rate: u32) -> *mut c_void {
    let processor = match Processor::new(sample_rate) {
        Ok(processor) => processor,
        Err(error) => {
            eprintln!("[aec] failed to create processor at {sample_rate} Hz: {error}");
            return std::ptr::null_mut();
        }
    };

    processor.set_config(Config {
        echo_canceller: Some(EchoCanceller::Full {
            stream_delay_ms: None,
        }),
        high_pass_filter: Some(HighPassFilter::default()),
        ..Default::default()
    });

    let frame_size = processor.num_samples_per_frame();
    let state = Box::new(AecState {
        processor,
        frame_size,
    });
    Box::into_raw(state) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn aec_destroy(handle: *mut c_void) {
    if handle.is_null() {
        return;
    }

    unsafe {
        drop(Box::from_raw(handle as *mut AecState));
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn aec_get_frame_size(handle: *const c_void) -> usize {
    if handle.is_null() {
        return 0;
    }

    let state = unsafe { &*(handle as *const AecState) };
    state.frame_size
}

#[unsafe(no_mangle)]
pub extern "C" fn aec_analyze_render(
    handle: *const c_void,
    samples: *const f32,
    count: usize,
) -> i32 {
    if handle.is_null() || samples.is_null() {
        return -5;
    }

    let state = unsafe { &*(handle as *const AecState) };
    if state.frame_size == 0 || count % state.frame_size != 0 {
        return -8;
    }

    let data = unsafe { slice::from_raw_parts(samples, count) };
    for chunk in data.chunks_exact(state.frame_size) {
        if let Err(error) = state.processor.analyze_render_frame([chunk]) {
            eprintln!("[aec] analyze_render failed: {error}");
            return error_code(error);
        }
    }

    0
}

#[unsafe(no_mangle)]
pub extern "C" fn aec_process_render(handle: *mut c_void, samples: *mut f32, count: usize) -> i32 {
    if handle.is_null() || samples.is_null() {
        return -5;
    }

    let state = unsafe { &*(handle as *const AecState) };
    if state.frame_size == 0 || count % state.frame_size != 0 {
        return -8;
    }

    let data = unsafe { slice::from_raw_parts_mut(samples, count) };
    for chunk in data.chunks_exact_mut(state.frame_size) {
        if let Err(error) = state.processor.process_render_frame([chunk]) {
            eprintln!("[aec] process_render failed: {error}");
            return error_code(error);
        }
    }

    0
}

#[unsafe(no_mangle)]
pub extern "C" fn aec_process_capture(handle: *mut c_void, samples: *mut f32, count: usize) -> i32 {
    if handle.is_null() || samples.is_null() {
        return -5;
    }

    let state = unsafe { &*(handle as *const AecState) };
    if state.frame_size == 0 || count % state.frame_size != 0 {
        return -8;
    }

    let data = unsafe { slice::from_raw_parts_mut(samples, count) };
    for chunk in data.chunks_exact_mut(state.frame_size) {
        if let Err(error) = state.processor.process_capture_frame([chunk]) {
            eprintln!("[aec] process_capture failed: {error}");
            return error_code(error);
        }
    }

    0
}
